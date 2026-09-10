import type { SupabaseClient } from "@supabase/supabase-js";

const AVATAR_BUCKET = "profile-avatars";
const LOGO_BUCKET = "workspace-logos";

type StoredObject = { name: string; created_at: string };
type ReferenceRow = Record<string, string | null>;

/** Pure helper so orphan selection stays unit-testable without a database. */
export function selectOrphans(
  paths: string[],
  referenced: Array<string | null | undefined>,
): string[] {
  const used = new Set(referenced.filter((value): value is string => Boolean(value)));
  return paths.filter((path) => !used.has(path));
}

async function bucketOrphans(
  client: SupabaseClient,
  bucket: string,
  table: string,
  column: string,
  olderThan: Date,
  limit: number,
): Promise<{ scanned: number; orphanPaths: string[] }> {
  const { data, error } = await client.schema("storage").from("objects")
    .select("name,created_at")
    .eq("bucket_id", bucket)
    .lt("created_at", olderThan.toISOString())
    .order("created_at", { ascending: true })
    .limit(Math.max(1, Math.min(limit, 1_000)));
  if (error) throw error;
  const objects = (data ?? []) as StoredObject[];
  if (objects.length === 0) return { scanned: 0, orphanPaths: [] };

  const paths = objects.map((object) => object.name);
  const { data: referenced, error: referenceError } = await client
    .from(table)
    .select(column)
    .in(column, paths);
  if (referenceError) throw referenceError;
  const used = ((referenced ?? []) as unknown as ReferenceRow[])
    .map((row) => row[column])
    .filter((value): value is string => typeof value === "string");
  return { scanned: paths.length, orphanPaths: selectOrphans(paths, used) };
}

export async function cleanupOrphanProfileMedia(
  client: SupabaseClient,
  olderThan: Date,
  limit = 500,
): Promise<{
  scanned: number;
  deleted: number;
  avatars_deleted: number;
  logos_deleted: number;
}> {
  const avatars = await bucketOrphans(
    client,
    AVATAR_BUCKET,
    "profiles",
    "avatar_object_path",
    olderThan,
    limit,
  );
  const logos = await bucketOrphans(
    client,
    LOGO_BUCKET,
    "workspaces",
    "logo_object_path",
    olderThan,
    limit,
  );

  let avatarsDeleted = 0;
  let logosDeleted = 0;
  if (avatars.orphanPaths.length > 0) {
    const { error } = await client.storage.from(AVATAR_BUCKET).remove(avatars.orphanPaths);
    if (error) throw error;
    avatarsDeleted = avatars.orphanPaths.length;
  }
  if (logos.orphanPaths.length > 0) {
    const { error } = await client.storage.from(LOGO_BUCKET).remove(logos.orphanPaths);
    if (error) throw error;
    logosDeleted = logos.orphanPaths.length;
  }
  return {
    scanned: avatars.scanned + logos.scanned,
    deleted: avatarsDeleted + logosDeleted,
    avatars_deleted: avatarsDeleted,
    logos_deleted: logosDeleted,
  };
}
