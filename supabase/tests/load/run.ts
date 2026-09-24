type ErrorEnvelope = {
  error?: { code?: string; retryable?: boolean } | null;
};

type Metric = {
  operation: string;
  count: number;
  p50_ms: number;
  p95_ms: number;
  p99_ms: number;
  max_ms: number;
  target_p95_ms: number;
};

type TimedResponse<T> = {
  body: T;
  durationMs: number;
};

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment: ${name}`);
  return value;
};

const positiveIntegerEnv = (name: string, fallback: number): number => {
  const raw = Deno.env.get(name);
  const value = raw === undefined ? fallback : Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return value;
};

const apiUrl = requiredEnv("API_URL");
const restUrl = requiredEnv("REST_URL");
const functionsUrl = requiredEnv("FUNCTIONS_URL");
const publishableKey = Deno.env.get("PUBLISHABLE_KEY") ?? requiredEnv("ANON_KEY");
const serviceRoleKey = requiredEnv("SERVICE_ROLE_KEY");
const bookingCount = positiveIntegerEnv("LOAD_BOOKING_COUNT", 1_000);
const concurrency = positiveIntegerEnv("LOAD_CONCURRENCY", 25);
const resolveCount = positiveIntegerEnv("LOAD_RESOLVE_COUNT", 100);
const qrCount = Math.min(positiveIntegerEnv("LOAD_QR_COUNT", 50), bookingCount, 250);
const dashboardCount = positiveIntegerEnv("LOAD_DASHBOARD_COUNT", 100);

const jsonHeaders = {
  "content-type": "application/json",
};

const safeErrorCode = (value: unknown): string => {
  if (!value || typeof value !== "object") return "INVALID_RESPONSE";
  const envelope = value as ErrorEnvelope;
  return envelope.error?.code ?? "REQUEST_FAILED";
};

const MAX_ATTEMPTS = 4;
const RETRY_BASE_DELAY_MS = 250;
// Gateway/isolate-level 5xx carry no function error envelope. smoke.sh
// already retries this exact class around create-booking on CI runners.
const TRANSIENT_STATUSES = new Set([500, 502, 503, 504]);

const sleep = (milliseconds: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));

const retryDelayMs = (attempt: number): number =>
  RETRY_BASE_DELAY_MS * 2 ** (attempt - 1) + Math.random() * RETRY_BASE_DELAY_MS;

const envelopeRetryable = (value: unknown): boolean =>
  !!value && typeof value === "object" &&
  (value as ErrorEnvelope).error?.retryable === true;

const bodySummary = (value: unknown): string => {
  try {
    const text = JSON.stringify(value) ?? "null";
    return text.length > 200 ? `${text.slice(0, 200)}...` : text;
  } catch {
    return "[unserializable response body]";
  }
};

let retryAttempts = 0;

type AttemptOutcome<T> =
  | { kind: "success"; body: T; durationMs: number }
  | { kind: "failure"; error: Error; retryable: boolean };

async function attemptJson<T>(
  url: string,
  init: RequestInit,
  expectedStatuses: readonly number[],
): Promise<AttemptOutcome<T>> {
  const startedAt = performance.now();
  let response: Response;
  try {
    response = await fetch(url, init);
  } catch (error) {
    // Transport-level failure, e.g. a dropped connection while the edge
    // runtime recycles an isolate mid-burst.
    return {
      kind: "failure",
      error: error instanceof Error ? error : new Error(String(error)),
      retryable: true,
    };
  }
  const durationMs = performance.now() - startedAt;
  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return {
      kind: "failure",
      error: new Error(`HTTP ${response.status}: INVALID_JSON_RESPONSE`),
      retryable: TRANSIENT_STATUSES.has(response.status),
    };
  }
  if (expectedStatuses.includes(response.status)) {
    return { kind: "success", body: body as T, durationMs };
  }
  return {
    kind: "failure",
    error: new Error(`HTTP ${response.status}: ${safeErrorCode(body)} ${bodySummary(body)}`),
    // Deterministic 4xx business rejections never recover on retry; only
    // gateway-level 5xx or contract-retryable envelopes are worth retrying.
    // 429 is excluded even though the contract marks it retryable: this
    // harness uses unique fingerprints, so a rate hit signals a test-design
    // defect, and retrying would only burn the shared bucket on the way out.
    retryable: response.status !== 429 &&
      (TRANSIENT_STATUSES.has(response.status) || envelopeRetryable(body)),
  };
}

async function requestJson<T>(
  url: string,
  init: RequestInit,
  expectedStatuses: readonly number[],
): Promise<TimedResponse<T>> {
  let lastFailure: Error | undefined;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    if (attempt > 1) {
      retryAttempts += 1;
      const reason = lastFailure?.message ?? "unknown failure";
      console.error(
        `Retrying ${url} after ${reason} (attempt ${attempt}/${MAX_ATTEMPTS})`,
      );
    }
    const outcome = await attemptJson<T>(url, init, expectedStatuses);
    if (outcome.kind === "success") {
      return { body: outcome.body, durationMs: outcome.durationMs };
    }
    lastFailure = outcome.error;
    if (!outcome.retryable || attempt === MAX_ATTEMPTS) break;
    await sleep(retryDelayMs(attempt));
  }
  throw lastFailure ?? new Error("REQUEST_FAILED");
}

async function parallelMap<T>(
  count: number,
  workerCount: number,
  operation: (index: number) => Promise<T>,
): Promise<T[]> {
  const results = new Array<T>(count);
  let nextIndex = 0;
  let failed = false;
  const workers = Array.from({ length: Math.min(count, workerCount) }, async () => {
    while (!failed) {
      const index = nextIndex++;
      if (index >= count) return;
      try {
        results[index] = await operation(index);
      } catch (error) {
        // Stop claiming new work after the first hard failure; in-flight
        // requests finish on their own and Promise.all rejects.
        failed = true;
        throw error;
      }
    }
  });
  await Promise.all(workers);
  return results;
}

const percentile = (values: number[], percentileValue: number): number => {
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.max(0, Math.ceil((percentileValue / 100) * sorted.length) - 1);
  return sorted[index];
};

const rounded = (value: number): number => Math.round(value * 100) / 100;

const metric = (
  operation: string,
  durations: number[],
  targetP95Ms: number,
): Metric => ({
  operation,
  count: durations.length,
  p50_ms: rounded(percentile(durations, 50)),
  p95_ms: rounded(percentile(durations, 95)),
  p99_ms: rounded(percentile(durations, 99)),
  max_ms: rounded(Math.max(...durations)),
  target_p95_ms: targetP95Ms,
});

const loadFingerprintHeaders = (index: number, phase: string): Record<string, string> => ({
  "x-client-instance-id": `load-${phase}-${index}`,
  "x-forwarded-for": `10.${Math.floor(index / 65_536) % 256}.${Math.floor(index / 256) % 256}.${
    index % 256
  }`,
  "user-agent": "kumpul-local-load-test/1",
});

const organizerHeaders = (accessToken: string): Record<string, string> => ({
  apikey: publishableKey,
  authorization: `Bearer ${accessToken}`,
  ...jsonHeaders,
});

const rpcHeaders = (accessToken: string): Record<string, string> => ({
  ...organizerHeaders(accessToken),
  "content-profile": "api",
  "accept-profile": "api",
});

const publicHeaders = (index: number, phase: string): Record<string, string> => ({
  apikey: publishableKey,
  ...jsonHeaders,
  ...loadFingerprintHeaders(index, phase),
});

const phoneFor = (index: number): string => `0812${String(index).padStart(8, "0")}`;

let userId: string | undefined;

try {
  const suffix = crypto.randomUUID();
  const email = `backend-load-${suffix}@example.invalid`;
  const password = `BackendLoad-${suffix}`;

  const createdUser = await requestJson<{ id: string }>(
    `${apiUrl}/auth/v1/admin/users`,
    {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        ...jsonHeaders,
      },
      body: JSON.stringify({ email, password, email_confirm: true }),
    },
    [200],
  );
  userId = createdUser.body.id;

  const session = await requestJson<{ access_token: string }>(
    `${apiUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: { apikey: publishableKey, ...jsonHeaders },
      body: JSON.stringify({ email, password }),
    },
    [200],
  );
  const accessToken = session.body.access_token;

  // Workspaces are provisioned during onboarding (admin role), not at signup.
  await requestJson<{ role: string }>(
    `${restUrl}/rpc/complete_onboarding_v1`,
    {
      method: "POST",
      headers: rpcHeaders(accessToken),
      body: JSON.stringify({ p_role: "admin" }),
    },
    [200],
  );

  await requestJson<{ id: string }>(
    `${restUrl}/rpc/update_workspace_profile_v1`,
    {
      method: "POST",
      headers: rpcHeaders(accessToken),
      body: JSON.stringify({
        p_name: "Load Test Workspace",
        p_address: "Synthetic load test address",
        p_phone_e164: "+6281234567890",
        p_email: email,
        p_logo_object_path: "",
      }),
    },
    [200],
  );

  const workspaces = await requestJson<Array<{ id: string }>>(
    `${restUrl}/workspaces?select=id&owner_user_id=eq.${encodeURIComponent(userId)}`,
    { headers: organizerHeaders(accessToken) },
    [200],
  );
  const workspaceId = workspaces.body[0]?.id;
  if (!workspaceId) throw new Error("Load test workspace bootstrap failed");

  const startAt = new Date(Date.now() - 60 * 60 * 1_000).toISOString();
  const endAt = new Date(Date.now() + 24 * 60 * 60 * 1_000).toISOString();
  const draft = await requestJson<{ id: string }>(
    `${restUrl}/rpc/upsert_event_draft_v1`,
    {
      method: "POST",
      headers: rpcHeaders(accessToken),
      body: JSON.stringify({
        p_event_id: null,
        p_mutation_id: crypto.randomUUID(),
        p_payload: {
          name: "Local Load Event",
          description: "Synthetic non-PII load test event",
          start_at: startAt,
          end_at: endAt,
          timezone_name: "Asia/Jakarta",
          operational_days: [1, 2, 3, 4, 5, 6, 7],
          opens_at_local: "00:00:00",
          closes_at_local: "23:59:59",
          location_name: "Jakarta",
          location_address: "Synthetic load test location",
          location_country_code: "ID",
          latitude: -6.2,
          longitude: 106.8,
          capacity_grams: 550_000,
          banner_object_path: `${workspaceId}/load/banner.jpg`,
          receiver_name: "Load Test Receiver",
          receiver_phone: "+6281234567890",
          receiver_address: "Synthetic load test receiver",
          criteria: ["cotton"],
        },
      }),
    },
    [200],
  );
  const eventId = draft.body.id;

  const published = await requestJson<{
    data: { invocation_url: string };
  }>(
    `${functionsUrl}/publish-event`,
    {
      method: "POST",
      headers: organizerHeaders(accessToken),
      body: JSON.stringify({ event_id: eventId }),
    },
    [200],
  );
  const invocationUrl = new URL(published.body.data.invocation_url);
  const invocationToken = invocationUrl.searchParams.get("event");
  if (!invocationToken) throw new Error("Publish response omitted the invocation token");

  // A cold resolve-event isolate sheds the first 25-way burst with gateway
  // 5xx on the 2-vCPU CI runner. Warm it with one deterministic 404 (unknown
  // token, distinct fingerprint bucket) before the measured phase starts.
  await requestJson<ErrorEnvelope>(
    `${functionsUrl}/resolve-event?token=${encodeURIComponent("w".repeat(64))}`,
    { headers: publicHeaders(0, "warmup-resolve") },
    [404],
  );

  const resolveDurations = await parallelMap(resolveCount, concurrency, async (index) => {
    const response = await requestJson<ErrorEnvelope>(
      `${functionsUrl}/resolve-event?token=${encodeURIComponent(invocationToken)}`,
      { headers: publicHeaders(index, "resolve") },
      [200],
    );
    return response.durationMs;
  });

  // Same cold-isolate risk for the heaviest burst: one malformed request
  // boots the create-booking isolate and returns a deterministic 400
  // without creating any booking state.
  await requestJson<ErrorEnvelope>(
    `${functionsUrl}/create-booking`,
    {
      method: "POST",
      headers: {
        ...publicHeaders(0, "warmup-booking"),
        "idempotency-key": `load-warmup-${suffix}`,
      },
      body: "{",
    },
    [400],
  );

  const bookings = await parallelMap(bookingCount, concurrency, async (index) => {
    const response = await requestJson<{
      data: { booking_id: string; qr_token: string; idempotent_replay: boolean };
    }>(
      `${functionsUrl}/create-booking`,
      {
        method: "POST",
        headers: {
          ...publicHeaders(index, "booking"),
          "idempotency-key": `load-booking-${suffix}-${index}`,
        },
        body: JSON.stringify({
          invocation_token: invocationToken,
          donor_name: `Synthetic Donor ${index}`,
          phone: phoneFor(index),
          estimated_weight_grams: 500,
          item_count: 1,
          items: [{
            ordinal: 0,
            passed: true,
            scanner_model_version: "load-test-v1",
            metadata: { garment_type: "shirt", sensitivity: "medium" },
          }],
          shipping_method: "direct",
          scan_model_version: "load-test-v1",
          terms_version: "local-v1",
          privacy_version: "local-v1",
        }),
      },
      // A retried request replays idempotently, which the contract answers
      // with 200 instead of the fresh-creation 201; both are valid here.
      [200, 201],
    );
    return {
      durationMs: response.durationMs,
      publicBookingId: response.body.data.booking_id,
      qrToken: response.body.data.qr_token,
      idempotentReplay: response.body.data.idempotent_replay,
    };
  });

  // Warm the resolve-qr isolate with an unknown token (deterministic 404).
  await requestJson<ErrorEnvelope>(
    `${functionsUrl}/resolve-qr`,
    {
      method: "POST",
      headers: organizerHeaders(accessToken),
      body: JSON.stringify({ qr_token: "q".repeat(64) }),
    },
    [404],
  );

  const qrResolutions = await parallelMap(qrCount, concurrency, async (index) => {
    const response = await requestJson<{
      data: { booking_id: string };
    }>(
      `${functionsUrl}/resolve-qr`,
      {
        method: "POST",
        headers: organizerHeaders(accessToken),
        body: JSON.stringify({ qr_token: bookings[index].qrToken }),
      },
      [200],
    );
    return { durationMs: response.durationMs, bookingId: response.body.data.booking_id };
  });

  const decisionDurations = await parallelMap(qrCount, concurrency, async (index) => {
    const response = await requestJson<Record<string, unknown>>(
      `${restUrl}/rpc/decide_reception_v1`,
      {
        method: "POST",
        headers: rpcHeaders(accessToken),
        body: JSON.stringify({
          p_booking_id: qrResolutions[index].bookingId,
          p_decision: "accepted",
          p_actual_weight_grams: 1_000,
          p_condition: "good",
          p_rejection_reason: null,
          p_rejection_note: null,
          p_idempotency_key: `load-reception-${suffix}-${index}`,
          p_request_id: crypto.randomUUID(),
        }),
      },
      [200],
    );
    return response.durationMs;
  });

  const dashboardDurations = await parallelMap(
    dashboardCount,
    concurrency,
    async () => {
      const response = await requestJson<Record<string, unknown>>(
        `${restUrl}/rpc/recap_v1`,
        {
          method: "POST",
          headers: rpcHeaders(accessToken),
          body: JSON.stringify({ p_event_id: eventId }),
        },
        [200],
      );
      return response.durationMs;
    },
  );

  const metrics = [
    metric("resolve_event", resolveDurations, 800),
    // CI runners are much slower than dev machines, so the guardrails are
    // calibrated against the 2-vCPU ubuntu-latest baseline, not local Apple
    // Silicon numbers.
    metric("create_booking", bookings.map((booking) => booking.durationMs), 1_500),
    metric("resolve_qr", qrResolutions.map((resolution) => resolution.durationMs), 2_500),
    metric("accept_reception", decisionDurations, 1_500),
    metric("dashboard_recap", dashboardDurations, 1_500),
  ];
  console.log(JSON.stringify(
    {
      status: "completed",
      booking_count: bookingCount,
      concurrency,
      retry_attempts: retryAttempts,
      idempotent_replays: bookings.filter((booking) => booking.idempotentReplay).length,
      metrics,
    },
    null,
    2,
  ));

  const failedTargets = metrics.filter((entry) => entry.p95_ms > entry.target_p95_ms);
  if (failedTargets.length > 0) {
    throw new Error(
      `p95 target exceeded: ${failedTargets.map((entry) => entry.operation).join(", ")}`,
    );
  }
} finally {
  if (userId) {
    try {
      await fetch(`${apiUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
        method: "DELETE",
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
        },
      });
    } catch {
      console.error("Load fixture cleanup failed");
    }
  }
}
