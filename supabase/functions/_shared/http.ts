export type FieldErrors = Record<string, string>;

export class ApiError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    readonly retryable = false,
    readonly fieldErrors?: FieldErrors,
  ) {
    super(code);
  }
}

const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

export function success(data: unknown, requestId: string, status = 200): Response {
  return new Response(
    JSON.stringify({
      data,
      error: null,
      request_id: requestId,
      server_time: new Date().toISOString(),
    }),
    { status, headers: { ...jsonHeaders, "x-request-id": requestId } },
  );
}

export function failure(error: ApiError, requestId: string): Response {
  return new Response(
    JSON.stringify({
      data: null,
      error: {
        code: error.code,
        retryable: error.retryable,
        ...(error.fieldErrors ? { field_errors: error.fieldErrors } : {}),
      },
      request_id: requestId,
      server_time: new Date().toISOString(),
    }),
    { status: error.status, headers: { ...jsonHeaders, "x-request-id": requestId } },
  );
}

export function method(req: Request, expected: string): void {
  if (req.method !== expected) throw new ApiError("METHOD_NOT_ALLOWED", 405);
}

export async function readJson(req: Request, maxBytes = 32_768): Promise<Record<string, unknown>> {
  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("application/json")) {
    throw new ApiError("CONTENT_TYPE_REQUIRED", 415);
  }
  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new ApiError("PAYLOAD_TOO_LARGE", 413);
  }
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > maxBytes) {
    throw new ApiError("PAYLOAD_TOO_LARGE", 413);
  }
  try {
    const value = JSON.parse(text) as unknown;
    if (!value || Array.isArray(value) || typeof value !== "object") {
      throw new ApiError("INVALID_REQUEST", 400);
    }
    return value as Record<string, unknown>;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError("MALFORMED_JSON", 400);
  }
}

function mapUnknownError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;
  const message = error instanceof Error
    ? error.message
    : error && typeof error === "object" && "message" in error &&
        typeof error.message === "string"
    ? error.message
    : "";
  const known: Record<string, [number, boolean]> = {
    AUTH_REQUIRED: [401, false],
    WORKSPACE_UNAVAILABLE: [403, false],
    EVENT_NOT_FOUND: [404, false],
    BOOKING_NOT_FOUND: [404, false],
    BOOKING_UNAVAILABLE: [404, false],
    INVOCATION_INVALID: [404, false],
    QR_INVALID: [404, false],
    EVENT_TERMINAL: [409, false],
    EVENT_NOT_PUBLISHABLE: [409, false],
    EVENT_UNAVAILABLE: [409, false],
    EVENT_NOT_OPERATIONAL: [409, false],
    EVENT_FULL: [409, false],
    CAPACITY_EXCEEDED: [409, false],
    ACTIVE_EVENT_LIMIT: [409, false],
    IDEMPOTENCY_CONFLICT: [409, false],
    BOOKING_NOT_PROCESSABLE: [409, false],
    EVENT_PUBLISH_FIELDS_REQUIRED: [422, false],
    CONSENT_VERSION_INVALID: [422, false],
    INVALID_ITEMS: [422, false],
    ITEM_NOT_PASSED: [422, false],
  };
  for (const [code, [status, retryable]] of Object.entries(known)) {
    if (message.includes(code)) return new ApiError(code, status, retryable);
  }
  return new ApiError("INTERNAL_ERROR", 500, true);
}

export function logOutcome(
  requestId: string,
  functionName: string,
  startedAt: number,
  outcome: "success" | "error",
  code?: string,
): void {
  console.log(JSON.stringify({
    request_id: requestId,
    function: functionName,
    duration_ms: Date.now() - startedAt,
    outcome,
    ...(code ? { error_code: code } : {}),
  }));
}

export function serve(
  functionName: string,
  handler: (req: Request, requestId: string) => Promise<Response>,
): void {
  Deno.serve(async (req) => {
    const startedAt = Date.now();
    const headerId = req.headers.get("x-request-id");
    const requestId = headerId && /^[0-9a-f-]{36}$/i.test(headerId)
      ? headerId
      : crypto.randomUUID();
    try {
      const response = await handler(req, requestId);
      logOutcome(requestId, functionName, startedAt, "success");
      return response;
    } catch (error) {
      const apiError = mapUnknownError(error);
      logOutcome(requestId, functionName, startedAt, "error", apiError.code);
      return failure(apiError, requestId);
    }
  });
}
