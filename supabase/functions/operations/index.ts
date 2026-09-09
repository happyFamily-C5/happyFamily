import { decrypt, sha256Hex } from "../_shared/crypto.ts";
import { ApiError, method, readJson, serve, success } from "../_shared/http.ts";
import { organizerSession, rpc } from "../_shared/supabase.ts";

function uuid(value: unknown): string {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(value)) {
    throw new ApiError("INVALID_REQUEST", 400);
  }
  return value;
}

function optionalUuid(value: unknown): string | null {
  if (value === null || value === undefined || value === "") return null;
  return uuid(value);
}

type QRResult = Record<string, unknown> & {
  donor_name_ciphertext: string;
  donor_name_nonce: string;
  donor_phone_ciphertext: string;
  donor_phone_nonce: string;
  crypto_key_version: number;
};

serve("operations", async (req, requestId) => {
  method(req, "POST");
  const body = await readJson(req);
  const { client } = await organizerSession(req);
  const action = typeof body.action === "string" ? body.action : "";
  if (action === "upsert_event_draft") {
    const payload = body.payload;
    if (!payload || Array.isArray(payload) || typeof payload !== "object") {
      throw new ApiError("INVALID_REQUEST", 400);
    }
    return success(
      await rpc(client, "upsert_event_draft_v2", {
        p_event_id: optionalUuid(body.event_id),
        p_mutation_id: uuid(body.mutation_id),
        p_payload: payload,
      }),
      requestId,
    );
  }
  if (action === "publish_event") {
    return success(
      await rpc(client, "publish_event_v2", {
        p_event_id: uuid(body.event_id),
        p_request_id: requestId,
      }),
      requestId,
    );
  }
  if (action === "recap") {
    return success(
      await rpc(client, "admin_recap_v2", {
        p_days: typeof body.days === "number" ? body.days : 7,
      }),
      requestId,
    );
  }
  if (action === "donation_history") {
    return success(
      await rpc(client, "admin_donation_history_v1", { p_event_id: body.event_id ?? null }),
      requestId,
    );
  }
  if (action === "event_history") {
    return success(
      await rpc(client, "admin_event_history_v1", { p_event_id: body.event_id ?? null }),
      requestId,
    );
  }
  if (action === "cancel_or_delete_event") {
    return success(
      await rpc(client, "cancel_or_delete_event_v2", {
        p_event_id: uuid(body.event_id),
        p_request_id: requestId,
      }),
      requestId,
    );
  }
  if (action === "resolve_qr") {
    const token = typeof body.qr_token === "string" ? body.qr_token.trim() : "";
    if (token.length < 32 || token.length > 200) throw new ApiError("QR_INVALID", 404);
    const result = await rpc<QRResult>(client, "resolve_account_qr_v2", {
      p_qr_token_hash: await sha256Hex(token),
    });
    const {
      donor_name_ciphertext,
      donor_name_nonce,
      donor_phone_ciphertext,
      donor_phone_nonce,
      crypto_key_version,
      ...safe
    } = result;
    return success(
      {
        ...safe,
        donor_name: await decrypt(donor_name_ciphertext, donor_name_nonce, crypto_key_version),
        donor_phone: await decrypt(donor_phone_ciphertext, donor_phone_nonce, crypto_key_version),
      },
      requestId,
    );
  }
  if (action === "decide_reception") {
    const decision = body.decision;
    if (decision !== "accepted" && decision !== "rejected") {
      throw new ApiError("INVALID_REQUEST", 400);
    }
    const key = req.headers.get("idempotency-key")?.trim() ?? "";
    if (!/^[A-Za-z0-9._:-]{8,200}$/.test(key)) throw new ApiError("IDEMPOTENCY_KEY_REQUIRED", 400);
    return success(
      await rpc(client, "decide_reception_v2", {
        p_booking_id: uuid(body.booking_id),
        p_decision: decision,
        p_actual_weight_grams: decision === "accepted" ? body.actual_weight_grams : null,
        p_idempotency_key: key,
        p_request_id: requestId,
      }),
      requestId,
    );
  }
  if (action === "advance_tracking") {
    const status = body.status;
    if (status !== "processed" && status !== "recycled") throw new ApiError("INVALID_REQUEST", 400);
    return success(
      await rpc(client, "advance_booking_status_v1", {
        p_booking_id: uuid(body.booking_id),
        p_status: status,
        p_request_id: requestId,
      }),
      requestId,
    );
  }
  throw new ApiError("INVALID_REQUEST", 400);
});
