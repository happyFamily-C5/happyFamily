import { MAX_BANNER_BYTES, validateBannerImage } from "../_shared/banner-image.ts";
import { cleanupOrphanBanners } from "../_shared/banner-storage.ts";
import { ApiError, method, serve, success } from "../_shared/http.ts";
import { adminClient, organizerSession } from "../_shared/supabase.ts";

const bucket = "event-banners";
const maxMultipartOverhead = 64 * 1024;

// V2 Admin-only banner boundary. Multipart is intentionally isolated from the
// JSON operations API so image bytes are never embedded in a database payload.
serve("admin-banner", async (req, requestId) => {
  method(req, "POST");
  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("multipart/form-data;")) {
    throw new ApiError("CONTENT_TYPE_REQUIRED", 415);
  }
  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BANNER_BYTES + maxMultipartOverhead) {
    throw new ApiError("BANNER_TOO_LARGE", 413);
  }
  const { user } = await organizerSession(req);
  const form = await req.formData();
  if ([...form.keys()].some((field) => field !== "file")) throw new ApiError("UNKNOWN_FIELD", 422);
  const file = form.get("file");
  if (!(file instanceof File)) throw new ApiError("BANNER_REQUIRED", 422);
  const bytes = new Uint8Array(await file.arrayBuffer());
  const image = validateBannerImage(bytes, file.type);
  const client = adminClient();
  const { data: workspace, error } = await client.from("workspaces").select("id")
    .eq("owner_user_id", user.id).eq("status", "active").maybeSingle();
  if (error) throw error;
  if (!workspace) throw new ApiError("WORKSPACE_UNAVAILABLE", 403);
  const objectPath = `${workspace.id}/${crypto.randomUUID()}/banner.${image.extension}`;
  const { error: uploadError } = await client.storage.from(bucket).upload(objectPath, bytes, {
    cacheControl: "3600",
    contentType: image.contentType,
    upsert: false,
  });
  if (uploadError) throw new ApiError("BANNER_UPLOAD_FAILED", 503, true);
  cleanupOrphanBanners(client, new Date(Date.now() - 24 * 60 * 60 * 1_000), workspace.id, 100)
    .catch(() => undefined);
  return success(
    {
      object_path: objectPath,
      content_type: image.contentType,
      width: image.width,
      height: image.height,
    },
    requestId,
    201,
  );
});
