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
  if (error) throw error;
  return data as T;
}
