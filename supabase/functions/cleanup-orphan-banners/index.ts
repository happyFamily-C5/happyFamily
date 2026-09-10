import { cleanupOrphanBanners } from "../_shared/banner-storage.ts";
import { requireEnv } from "../_shared/env.ts";
import { ApiError, method, serve, success } from "../_shared/http.ts";
import { adminClient } from "../_shared/supabase.ts";

function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  let mismatch = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index += 1) {
    mismatch |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return mismatch === 0;
}

serve("cleanup-orphan-banners", async (req, requestId) => {
  method(req, "POST");
  const expected = requireEnv("BANNER_CLEANUP_SECRET");
  const received = req.headers.get("x-cron-secret") ?? "";
  if (!constantTimeEqual(received, expected)) throw new ApiError("AUTH_INVALID", 401);

  const client = adminClient();
  const { data: run, error: runError } = await client.from("job_runs")
    .insert({ job_name: "banner-orphan-cleanup", correlation_id: requestId })
    .select("id")
    .single();
  if (runError) throw runError;

  try {
    const result = await cleanupOrphanBanners(
      client,
      new Date(Date.now() - 24 * 60 * 60 * 1_000),
    );
    await client.from("job_runs").update({
      status: "succeeded",
      finished_at: new Date().toISOString(),
      processed_rows: result.deleted,
      metadata: { scanned: result.scanned },
    }).eq("id", run.id);
    return success(result, requestId);
  } catch (error) {
    await client.from("job_runs").update({
      status: "failed",
      finished_at: new Date().toISOString(),
      error_code: "BANNER_CLEANUP_FAILED",
    }).eq("id", run.id);
    throw error;
  }
});
