import { hmacHex } from "./crypto.ts";
import { ApiError } from "./http.ts";
import { adminClient, rpc } from "./supabase.ts";

type RateLimitResult = { allowed: boolean; remaining: number; reset_at: string };

export async function fingerprint(req: Request, extra = ""): Promise<string> {
  const forwarded = (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();
  const client = (req.headers.get("x-client-instance-id") ?? "ephemeral").slice(0, 128);
  const agent = (req.headers.get("user-agent") ?? "unknown").slice(0, 160);
  return await hmacHex(`${client}|${forwarded}|${agent}|${extra}`);
}

export async function enforceRateLimit(
  endpoint: string,
  fingerprintHash: string,
  windowSeconds: number,
  maxRequests: number,
): Promise<void> {
  const result = await rpc<RateLimitResult>(adminClient(), "consume_rate_limit_v1", {
    p_endpoint: endpoint,
    p_fingerprint_hash: fingerprintHash,
    p_window_seconds: windowSeconds,
    p_max_requests: maxRequests,
  });
  if (!result.allowed) throw new ApiError("RATE_LIMITED", 429, true);
}
