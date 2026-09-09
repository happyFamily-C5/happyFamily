import { ApiError } from "./http.ts";

export function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new ApiError("SERVER_MISCONFIGURED", 500, false);
  return value;
}

export function integerEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isInteger(value) && value > 0 ? value : fallback;
}

export function environment(): "local" | "staging" | "production" {
  const value = Deno.env.get("APP_ENVIRONMENT") ?? "local";
  if (value === "local" || value === "staging" || value === "production") return value;
  throw new ApiError("SERVER_MISCONFIGURED", 500);
}

export function publicBookingEnabled(): boolean {
  return (Deno.env.get("PUBLIC_BOOKING_ENABLED") ?? "true").toLowerCase() === "true";
}
