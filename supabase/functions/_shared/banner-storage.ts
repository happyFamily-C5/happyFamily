import type { SupabaseClient } from "@supabase/supabase-js";

const BANNER_BUCKET = "event-banners";

type StoredObject = { name: string; created_at: string };
type ReferencedEvent = { banner_object_path: string | null };

export async function cleanupOrphanBanners(
  client: SupabaseClient,
  olderThan: Date,
  workspaceId?: string,
  limit = 500,
): Promise<{ scanned: number; deleted: number }> {
  let query = client.schema("storage").from("objects")
    .select("name,created_at")
    .eq("bucket_id", BANNER_BUCKET)
    .lt("created_at", olderThan.toISOString())
    .order("created_at", { ascending: true })
    .limit(Math.max(1, Math.min(limit, 1_000)));
  if (workspaceId) query = query.like("name", `${workspaceId}/%`);
  const { data, error } = await query;
  if (error) throw error;
  const objects = (data ?? []) as StoredObject[];
  if (objects.length === 0) return { scanned: 0, deleted: 0 };

  const paths = objects.map((object) => object.name);
  const { data: referenced, error: referenceError } = await client
    .from("events")
    .select("banner_object_path")
    .in("banner_object_path", paths);
  if (referenceError) throw referenceError;
  const used = new Set(
    ((referenced ?? []) as ReferencedEvent[])
      .map((event) => event.banner_object_path)
      .filter(Boolean) as string[],
  );
  const orphanPaths = paths.filter((path) => !used.has(path));
  if (orphanPaths.length === 0) return { scanned: paths.length, deleted: 0 };

  const { error: removeError } = await client.storage.from(BANNER_BUCKET).remove(orphanPaths);
  if (removeError) throw removeError;
  return { scanned: paths.length, deleted: orphanPaths.length };
}
