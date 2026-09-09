import { ApiError } from "./http.ts";

export function normalizeIndonesianPhone(input: unknown): string {
  if (typeof input !== "string") {
    throw new ApiError("PHONE_INVALID", 422, false, { phone: "invalid" });
  }
  let digits = input.trim().replace(/[^0-9+]/g, "");
  if (digits.startsWith("+")) digits = digits.slice(1);
  if (digits.startsWith("0")) digits = `62${digits.slice(1)}`;
  if (!digits.startsWith("62")) digits = `62${digits}`;
  if (!/^628[1-9][0-9]{6,11}$/.test(digits)) {
    throw new ApiError("PHONE_INVALID", 422, false, { phone: "invalid" });
  }
  return `+${digits}`;
}
