// Hosted staging contract test. It never uses a service-role key or local
// Supabase/Docker. Supply only the project's public URL/key as environment
// variables; generated identities are removed separately through a narrowly
// scoped admin cleanup query after a successful run.

const url = Deno.env.get("KUMPUL_STAGING_URL");
const key = Deno.env.get("KUMPUL_STAGING_PUBLISHABLE_KEY");
const run = Deno.env.get("KUMPUL_E2E_RUN_ID");
const bannerPath = Deno.env.get("KUMPUL_E2E_BANNER_PATH");
if (!url || !key || !run || !bannerPath) {
  throw new Error("missing E2E environment");
}
const stagingUrl = url;
const publishableKey = key;
const runId = run;
const bannerFilePath = bannerPath;

type Session = { access_token: string; user: { id: string; email: string } };
type Envelope = {
  data?: Record<string, unknown>;
  error?: { code?: string; message?: string };
};

function invariant(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

async function jsonResponse(response: Response): Promise<Envelope> {
  const body = await response.json().catch(() => ({})) as Envelope;
  if (!response.ok) {
    throw new Error(
      `HTTP ${response.status}: ${body.error?.code ?? body.error?.message ?? "unknown"}`,
    );
  }
  return body;
}

async function signup(label: string): Promise<Session> {
  const response = await fetch(`${stagingUrl}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: publishableKey, "content-type": "application/json" },
    body: JSON.stringify({
      email: `kumpul-contract-e2e-${runId}-${label}@example.invalid`,
      password: `KumpulE2E!${runId.slice(0, 18)}Aa9`,
      data: { display_name: `E2E ${label}` },
    }),
  });
  const body = await jsonResponse(response) as unknown as {
    access_token?: string;
    user?: Session["user"];
  };
  invariant(
    body.access_token && body.user,
    `signup did not return a session for ${label}`,
  );
  return { access_token: body.access_token, user: body.user };
}

function headers(session?: Session, idempotencyKey?: string): HeadersInit {
  return {
    apikey: publishableKey,
    ...(session ? { authorization: `Bearer ${session.access_token}` } : {}),
    ...(idempotencyKey ? { "idempotency-key": idempotencyKey } : {}),
    "content-type": "application/json",
  };
}

async function account(
  session: Session,
  body: Record<string, unknown>,
  idempotencyKey?: string,
) {
  return await jsonResponse(
    await fetch(`${stagingUrl}/functions/v1/account`, {
      method: "POST",
      headers: headers(session, idempotencyKey),
      body: JSON.stringify(body),
    }),
  );
}

async function operations(
  session: Session,
  body: Record<string, unknown>,
  idempotencyKey?: string,
) {
  return await jsonResponse(
    await fetch(`${stagingUrl}/functions/v1/operations`, {
      method: "POST",
      headers: headers(session, idempotencyKey),
      body: JSON.stringify(body),
    }),
  );
}

function data(envelope: Envelope): Record<string, unknown> {
  invariant(
    envelope.data,
    `missing response data: ${JSON.stringify(envelope.error)}`,
  );
  return envelope.data;
}

async function storageUpload(
  session: Session,
  bucket: string,
  path: string,
  expected: number | number[],
) {
  const response = await fetch(
    `${stagingUrl}/storage/v1/object/${bucket}/${path}`,
    {
      method: "POST",
      headers: {
        apikey: publishableKey,
        authorization: `Bearer ${session.access_token}`,
        "content-type": "image/png",
        "x-upsert": "false",
      },
      body: Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10]),
    },
  );
  const allowed = Array.isArray(expected) ? expected : [expected];
  invariant(
    allowed.includes(response.status),
    `storage ${bucket}/${path}: expected ${allowed}, got ${response.status}`,
  );
}

async function banner(admin: Session): Promise<string> {
  const form = new FormData();
  form.set(
    "file",
    new File([await Deno.readFile(bannerFilePath)], "banner.jpg", {
      type: "image/jpeg",
    }),
  );
  const response = await fetch(`${stagingUrl}/functions/v1/admin-banner`, {
    method: "POST",
    headers: {
      apikey: publishableKey,
      authorization: `Bearer ${admin.access_token}`,
    },
    body: form,
  });
  const objectPath = data(await jsonResponse(response)).object_path;
  invariant(
    typeof objectPath === "string",
    "admin banner did not return object_path",
  );
  return objectPath;
}

function eventPayload(objectPath: string, capacity: number) {
  const now = new Date();
  return {
    name: `E2E ${runId}`,
    description: "Hosted authenticated contract fixture",
    banner_object_path: objectPath,
    start_at: new Date(now.getTime() - 60_000).toISOString(),
    end_at: new Date(now.getTime() + 86_400_000).toISOString(),
    timezone_name: "Asia/Jakarta",
    operational_days: [1, 2, 3, 4, 5, 6, 7],
    opens_at_local: "00:00",
    closes_at_local: "23:59",
    location_name: "E2E staging",
    location_address: "Jakarta",
    location_country_code: "ID",
    latitude: -6.2,
    longitude: 106.8,
    capacity_grams: capacity,
    max_donation_per_user_grams: 1000,
    criteria: ["cotton"],
    // These untrusted fields must never override the workspace receiver snapshot.
    receiver_name: "forged",
    receiver_phone: "+620000",
    receiver_address: "forged",
  };
}

async function draftAndPublish(
  admin: Session,
  objectPath: string,
  capacity: number,
  suffix: string,
) {
  const draft = data(
    await operations(admin, {
      action: "upsert_event_draft",
      mutation_id: crypto.randomUUID(),
      payload: eventPayload(objectPath, capacity),
    }),
  );
  const eventId = draft.id;
  invariant(typeof eventId === "string", "draft did not return event id");
  const published = await operations(admin, {
    action: "publish_event",
    event_id: eventId,
  }, `publish-${runId}-${suffix}`);
  invariant(
    data(published).status === "ongoing",
    "event was not published as ongoing",
  );
  return eventId;
}

function booking(eventId: string, weight: number) {
  return {
    action: "create_booking",
    event_id: eventId,
    booking: {
      estimated_weight_grams: weight,
      item_count: 1,
      items: [{
        ordinal: 0,
        passed: true,
        scanner_model_version: "e2e-v1",
        metadata: {},
      }],
      shipping_method: "direct",
      scan_model_version: "e2e-v1",
    },
  };
}

async function main() {
  // Gateway JWT enforcement for every authenticated v2 edge boundary.
  for (const endpoint of ["account", "operations", "admin-banner"]) {
    const response = await fetch(`${stagingUrl}/functions/v1/${endpoint}`, {
      method: "POST",
    });
    invariant(
      response.status === 401,
      `${endpoint} accepted a missing JWT (${response.status})`,
    );
  }

  const [admin, adminOther, donorA, donorB] = await Promise.all([
    signup("admin"),
    signup("admin-other"),
    signup("donor-a"),
    signup("donor-b"),
  ]);
  await account(admin, { action: "complete_onboarding", role: "admin" });
  await account(adminOther, { action: "complete_onboarding", role: "admin" });
  await Promise.all([
    account(donorA, { action: "complete_onboarding", role: "donor" }),
    account(donorB, { action: "complete_onboarding", role: "donor" }),
  ]);
  const workspace = data(
    await account(admin, {
      action: "update_workspace",
      name: `E2E Workspace ${runId}`,
      address: "Jakarta",
      phone_e164: "+628111111111",
      email: `workspace-${runId}@example.invalid`,
      logo_object_path: "",
    }),
  );
  const workspaceId = workspace.id;
  invariant(typeof workspaceId === "string", "workspace id missing");
  await account(adminOther, {
    action: "update_workspace",
    name: `E2E Other Workspace ${runId}`,
    address: "Jakarta",
    phone_e164: "+628111111114",
    email: `workspace-other-${runId}@example.invalid`,
    logo_object_path: "",
  });

  // Storage RLS: each donor is isolated; only the active workspace admin may write its branding path.
  await storageUpload(
    donorA,
    "profile-avatars",
    `${donorA.user.id}/avatar.png`,
    [200, 201],
  );
  await storageUpload(
    donorA,
    "profile-avatars",
    `${donorB.user.id}/forbidden.png`,
    [400, 403],
  );
  await storageUpload(admin, "workspace-logos", `${workspaceId}/logo.png`, [
    200,
    201,
  ]);
  await storageUpload(
    donorA,
    "workspace-logos",
    `${workspaceId}/forbidden.png`,
    [400, 403],
  );
  await account(donorA, {
    action: "update_profile",
    display_name: "E2E Donor A",
    phone_e164: "+628111111112",
    address: "Jakarta",
    location_label: "Jakarta",
    latitude: -6.2,
    longitude: 106.8,
    avatar_object_path: `${donorA.user.id}/avatar.png`,
  });
  await account(donorB, {
    action: "update_profile",
    display_name: "E2E Donor B",
    phone_e164: "+628111111113",
    address: "Jakarta",
    location_label: "Jakarta",
    latitude: -6.2,
    longitude: 106.8,
    avatar_object_path: "",
  });

  const bannerPath = await banner(admin);
  const eventId = await draftAndPublish(admin, bannerPath, 2_000, "primary");
  const foreignEventId = await draftAndPublish(
    adminOther,
    await banner(adminOther),
    2_000,
    "other-workspace",
  );
  const eventPage = data(await operations(admin, { action: "list_events", limit: 100 }));
  invariant(
    Array.isArray(eventPage.items) && eventPage.items.some((event) =>
      typeof event === "object" && event !== null && (event as { id?: unknown }).id === eventId
    ),
    "operations list_events did not return the published event",
  );
  invariant(
    Array.isArray(eventPage.items) && !eventPage.items.some((event) =>
      typeof event === "object" && event !== null &&
        (event as { id?: unknown }).id === foreignEventId
    ),
    "operations list_events leaked another workspace event",
  );
  invariant(
    "next_cursor" in eventPage,
    "operations list_events did not return next_cursor",
  );
  const detailBefore = data(
    await account(donorA, { action: "event_detail", event_id: eventId }),
  );
  invariant(
    (detailBefore.availability as { bookable?: boolean }).bookable === true,
    "fresh event is not bookable",
  );
  const bookingKey = `booking-${runId}-primary`;
  const created = data(
    await account(donorA, booking(eventId, 300), bookingKey),
  );
  const bookingId = created.booking_id;
  const qrToken = created.qr_token;
  invariant(
    typeof bookingId === "string" && typeof qrToken === "string",
    "booking id or QR token missing",
  );
  const replay = data(await account(donorA, booking(eventId, 300), bookingKey));
  invariant(
    replay.booking_id === bookingId && replay.idempotent_replay === true,
    "booking retry was not idempotent",
  );
  const detailAfter = data(
    await account(donorA, { action: "event_detail", event_id: eventId }),
  );
  invariant(
    (detailAfter.availability as { bookable?: boolean }).bookable === false &&
      detailAfter.already_booked === true,
    "bookable did not close for an existing donor booking",
  );
  const resolved = data(
    await operations(admin, { action: "resolve_qr", qr_token: qrToken }),
  );
  invariant(
    resolved.booking_id === bookingId,
    "authenticated QR resolve returned the wrong booking",
  );
  const accepted = data(
    await operations(admin, {
      action: "decide_reception",
      booking_id: bookingId,
      decision: "accepted",
      actual_weight_grams: 300,
    }, `accept-${runId}-primary`),
  );
  invariant(accepted.status === "accepted", "reception did not accept booking");
  const processed = await operations(admin, {
    action: "advance_tracking",
    booking_id: bookingId,
    status: "processed",
  }, `processed-${runId}-primary`);
  const processedReplay = data(
    await operations(admin, {
      action: "advance_tracking",
      booking_id: bookingId,
      status: "processed",
    }, `processed-${runId}-primary`),
  );
  invariant(
    data(processed).status === "processed" &&
      processedReplay.status === "processed",
    "tracking retry was not idempotent",
  );
  const recycled = data(
    await operations(admin, {
      action: "advance_tracking",
      booking_id: bookingId,
      status: "recycled",
    }, `recycled-${runId}-primary`),
  );
  invariant(recycled.status === "recycled", "tracking did not recycle booking");
  const donorDetail = data(
    await account(donorA, { action: "booking_detail", booking_id: bookingId }),
  );
  invariant(
    donorDetail.status === "recycled",
    "donor tracking detail is stale",
  );
  invariant(
    Array.isArray(
      data(await account(donorA, { action: "donation_history", limit: 1 }))
        .items,
    ),
    "donor donation history is unavailable",
  );
  invariant(
    Array.isArray(
      data(await operations(admin, { action: "donation_history", limit: 1 }))
        .items,
    ),
    "admin donation history is unavailable",
  );
  invariant(
    Array.isArray(
      data(await operations(admin, { action: "recap", days: 7 })).daily,
    ),
    "admin daily recap is unavailable",
  );

  // Race: only one of two actual 700g receptions may fit in a 1000g event.
  const raceEvent = await draftAndPublish(admin, bannerPath, 1_000, "race");
  const [first, second] = await Promise.all([
    account(donorA, booking(raceEvent, 300), `booking-${runId}-race-a`),
    account(donorB, booking(raceEvent, 300), `booking-${runId}-race-b`),
  ]);
  const raceA = data(first).booking_id;
  const raceB = data(second).booking_id;
  invariant(
    typeof raceA === "string" && typeof raceB === "string",
    "race bookings missing",
  );
  const decisions = await Promise.allSettled([
    operations(admin, {
      action: "decide_reception",
      booking_id: raceA,
      decision: "accepted",
      actual_weight_grams: 700,
    }, `accept-${runId}-race-a`),
    operations(admin, {
      action: "decide_reception",
      booking_id: raceB,
      decision: "accepted",
      actual_weight_grams: 700,
    }, `accept-${runId}-race-b`),
  ]);
  const successes = decisions.filter((result) => result.status === "fulfilled");
  const failures = decisions.filter((result) =>
    result.status === "rejected"
  ) as PromiseRejectedResult[];
  invariant(
    successes.length === 1 && failures.length === 1 &&
      failures[0].reason.message.includes("CAPACITY_EXCEEDED"),
    "race did not produce exactly one CAPACITY_EXCEEDED rejection",
  );

  console.log(
    JSON.stringify({
      run: runId,
      emails: [admin.user.email, donorA.user.email, donorB.user.email],
      primary_event_id: eventId,
      race_event_id: raceEvent,
      result: "passed",
    }),
  );
}

await main();
