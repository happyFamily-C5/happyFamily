import { sha256Hex } from "../_shared/crypto.ts";
import { ApiError, method, serve, success } from "../_shared/http.ts";
import { enforceRateLimit, fingerprint } from "../_shared/rate-limit.ts";
import { adminClient, rpc } from "../_shared/supabase.ts";

serve("resolve-event", async (req, requestId) => {
  method(req, "GET");
  const token = new URL(req.url).searchParams.get("token")?.trim() ?? "";
  if (token.length < 32 || token.length > 200) throw new ApiError("INVOCATION_INVALID", 404);
  await enforceRateLimit("resolve-event", await fingerprint(req, token.slice(0, 12)), 60, 60);
  const data = await rpc<Record<string, unknown>>(adminClient(), "resolve_event_v1", {
    p_token_hash: await sha256Hex(token),
  });
  return success(data, requestId);
});
