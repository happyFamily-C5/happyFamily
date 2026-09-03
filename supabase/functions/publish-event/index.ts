import { activeEncryptionKeyVersion, decrypt, encrypt, sha256Hex } from "../_shared/crypto.ts";
import { environment, requireEnv } from "../_shared/env.ts";
import { ApiError, method, readJson, serve, success } from "../_shared/http.ts";
import { opaqueToken } from "../_shared/ids.ts";
import { adminClient, organizerSession, rpc } from "../_shared/supabase.ts";

type PublishResult = {
  event: Record<string, unknown>;
  invocation_ciphertext: string;
  invocation_nonce: string;
  crypto_key_version: number;
};

serve("publish-event", async (req, requestId) => {
  method(req, "POST");
  const body = await readJson(req, 4_096);
  const eventId = typeof body.event_id === "string" ? body.event_id : "";
  if (!/^[0-9a-f-]{36}$/i.test(eventId)) throw new ApiError("EVENT_ID_INVALID", 422);
  const { user } = await organizerSession(req);
  const token = opaqueToken();
  const keyVersion = activeEncryptionKeyVersion();
  const protectedToken = await encrypt(token, keyVersion);
  const result = await rpc<PublishResult>(adminClient(), "publish_event_v1", {
    p_actor_id: user.id,
    p_event_id: eventId,
    p_token_hash: await sha256Hex(token),
    p_token_ciphertext: protectedToken.ciphertext,
    p_token_nonce: protectedToken.nonce,
    p_crypto_key_version: keyVersion,
    p_environment: environment(),
    p_request_id: requestId,
  });
  const invocation = await decrypt(
    result.invocation_ciphertext,
    result.invocation_nonce,
    result.crypto_key_version,
  );
  const base = requireEnv("APP_CLIP_BASE_URL").replace(/\/$/, "");
  return success({
    event: result.event,
    invocation_url: `${base}?event=${encodeURIComponent(invocation)}`,
  }, requestId);
});
