import { createDonorToken, hmacHex } from "../_shared/crypto.ts";
import { ApiError, method, readJson, serve, success } from "../_shared/http.ts";
import { normalizeIndonesianPhone } from "../_shared/phone.ts";
import { enforceRateLimit, fingerprint } from "../_shared/rate-limit.ts";
import { adminClient, rpc } from "../_shared/supabase.ts";

serve("verify-donor-booking", async (req, requestId) => {
  method(req, "POST");
  const body = await readJson(req, 4_096);
  const bookingId = typeof body.booking_id === "string" ? body.booking_id.trim().toUpperCase() : "";
  if (!/^KPL-[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$/.test(bookingId)) {
    throw new ApiError("BOOKING_CREDENTIALS_INVALID", 401);
  }
  let phone: string;
  try {
    phone = normalizeIndonesianPhone(body.phone);
  } catch {
    throw new ApiError("BOOKING_CREDENTIALS_INVALID", 401);
  }
  const pairFingerprint = await fingerprint(req, bookingId);
  await enforceRateLimit("donor-lookup-pair", pairFingerprint, 900, 5);
  await enforceRateLimit("donor-lookup-global", await fingerprint(req), 3_600, 20);
  const bookingUuid = await rpc<string | null>(adminClient(), "verify_donor_booking_v1", {
    p_public_booking_id: bookingId,
    p_phone_lookup_hash: await hmacHex(phone),
  });
  if (!bookingUuid) throw new ApiError("BOOKING_CREDENTIALS_INVALID", 401);
  return success({ access_token: await createDonorToken(bookingUuid), expires_in: 600 }, requestId);
});
