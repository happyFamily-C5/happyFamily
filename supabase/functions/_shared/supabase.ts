import { createClient, SupabaseClient, User } from "@supabase/supabase-js";
import { requireEnv } from "./env.ts";
import { ApiError } from "./http.ts";

export function adminClient(): SupabaseClient {
  return createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function organizerSession(
  req: Request,
): Promise<{ user: User; client: SupabaseClient }> {
  const authorization = req.headers.get("authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
  if (!token) throw new ApiError("AUTH_REQUIRED", 401);
  // Hosted projects inject the new publishable key explicitly. The local CLI
  // currently exposes only SUPABASE_ANON_KEY inside the Edge runtime.
  const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY")?.trim() ||
    requireEnv("SUPABASE_ANON_KEY");
  const client = createClient(
    requireEnv("SUPABASE_URL"),
    publishableKey,
    {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    },
  );
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new ApiError("AUTH_INVALID", 401);
  return { user: data.user, client };
}

export async function rpc<T>(
  client: SupabaseClient,
  name: string,
  params: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await client.schema("api").rpc(name, params);
  if (error) {
    // The publish RPC puts its field-specific validation map in PostgreSQL's
    // exception detail. Preserve it in the public envelope instead of
    // flattening it to the generic error code.
    if (error.message.includes("EVENT_PUBLISH_FIELDS_REQUIRED") && error.details) {
      try {
        const fieldErrors: unknown = JSON.parse(error.details);
        if (fieldErrors && !Array.isArray(fieldErrors) && typeof fieldErrors === "object") {
          throw new ApiError(
            "EVENT_PUBLISH_FIELDS_REQUIRED",
            422,
            false,
            fieldErrors as Record<string, string>,
          );
        }
      } catch (parseError) {
        if (parseError instanceof ApiError) throw parseError;
      }
    }
    throw error;
  }
  return data as T;
}
