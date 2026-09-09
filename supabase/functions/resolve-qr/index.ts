import { decrypt, sha256Hex } from "../_shared/crypto.ts";
import { ApiError, method, readJson, serve, success } from "../_shared/http.ts";
import { adminClient, organizerSession, rpc } from "../_shared/supabase.ts";

type QRResult = Record<string, unknown> & {
  donor_name_ciphertext: string;
  donor_name_nonce: string;
  donor_phone_ciphertext: string;
  donor_phone_nonce: string;
  crypto_key_version: number;
};

serve("resolve-qr", async (req, requestId) => {
  method(req, "POST");
  const body = await readJson(req, 4_096);
  const token = typeof body.qr_token === "string" ? body.qr_token.trim() : "";
  if (token.length < 32 || token.length > 200) throw new ApiError("QR_INVALID", 404);
  const { user } = await organizerSession(req);
  const result = await rpc<QRResult>(adminClient(), "resolve_qr_v1", {
    p_actor_id: user.id,
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
  const donorName = await decrypt(donor_name_ciphertext, donor_name_nonce, crypto_key_version);
  const donorPhone = await decrypt(donor_phone_ciphertext, donor_phone_nonce, crypto_key_version);
  return success({ ...safe, donor_name: donorName, donor_phone: donorPhone }, requestId);
});
