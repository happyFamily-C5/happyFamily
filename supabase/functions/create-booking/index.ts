import {
  activeEncryptionKeyVersion,
  canonicalJson,
  decrypt,
  encrypt,
  hmacHex,
  sha256Hex,
} from "../_shared/crypto.ts";
import { publicBookingEnabled, requireEnv } from "../_shared/env.ts";
import { ApiError, method, readJson, serve, success } from "../_shared/http.ts";
import { opaqueToken, publicBookingId } from "../_shared/ids.ts";
import { normalizeIndonesianPhone } from "../_shared/phone.ts";
import { enforceRateLimit, fingerprint } from "../_shared/rate-limit.ts";
import { adminClient, rpc } from "../_shared/supabase.ts";
import { validateBooking } from "../_shared/validation.ts";

type BookingResult = {
  booking_id: string;
  public_booking_id: string;
  status: string;
  expires_at: string;
  event_snapshot: Record<string, unknown>;
  qr_token_ciphertext: string;
  qr_token_nonce: string;
  crypto_key_version: number;
  idempotent_replay: boolean;
};

serve("create-booking", async (req, requestId) => {
  method(req, "POST");
  if (!publicBookingEnabled()) throw new ApiError("PUBLIC_BOOKING_DISABLED", 503, true);
  const idempotencyKey = req.headers.get("idempotency-key")?.trim() ?? "";
  if (!/^[A-Za-z0-9._:-]{8,200}$/.test(idempotencyKey)) {
    throw new ApiError("IDEMPOTENCY_KEY_REQUIRED", 400);
  }
  const input = validateBooking(await readJson(req));
  const phone = normalizeIndonesianPhone(input.phone);
  const actorScope = await fingerprint(req, input.invocation_token.slice(0, 12));
  await enforceRateLimit("create-booking", actorScope, 600, 5);

  const keyVersion = activeEncryptionKeyVersion();
  const donorName = await encrypt(input.donor_name, keyVersion);
  const donorPhone = await encrypt(phone, keyVersion);
  const qrToken = opaqueToken();
  const protectedQr = await encrypt(qrToken, keyVersion);
  const result = await rpc<BookingResult>(adminClient(), "create_booking_v1", {
    p_invocation_token_hash: await sha256Hex(input.invocation_token),
    p_actor_scope: actorScope,
    p_idempotency_key: idempotencyKey,
    p_request_hash: await sha256Hex(canonicalJson({ ...input, phone })),
    p_booking: {
      public_booking_id: publicBookingId(),
      donor_name_ciphertext: donorName.ciphertext,
      donor_name_nonce: donorName.nonce,
      donor_phone_ciphertext: donorPhone.ciphertext,
      donor_phone_nonce: donorPhone.nonce,
      phone_lookup_hash: await hmacHex(phone),
      crypto_key_version: keyVersion,
      estimated_weight_grams: input.estimated_weight_grams,
      item_count: input.item_count,
      items: input.items,
      shipping_method: input.shipping_method,
      scan_model_version: input.scan_model_version,
      qr_token_hash: await sha256Hex(qrToken),
      qr_token_ciphertext: protectedQr.ciphertext,
      qr_token_nonce: protectedQr.nonce,
      terms_version: input.terms_version,
      privacy_version: input.privacy_version,
      request_id: requestId,
    },
  });
  const returnedQr = await decrypt(
    result.qr_token_ciphertext,
    result.qr_token_nonce,
    result.crypto_key_version,
  );
  const base = requireEnv("APP_CLIP_BASE_URL").replace(/\/$/, "");
  return success(
    {
      booking_id: result.public_booking_id,
      status: result.status,
      expires_at: result.expires_at,
      qr_token: returnedQr,
      qr_payload: `${base}/booking?qr=${encodeURIComponent(returnedQr)}`,
      label_snapshot: result.event_snapshot,
      idempotent_replay: result.idempotent_replay,
    },
    requestId,
    result.idempotent_replay ? 200 : 201,
  );
});
