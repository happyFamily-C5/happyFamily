import { randomToken } from "./crypto.ts";

const CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

function randomCharacters(length: number): string {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return [...bytes].map((value) => CROCKFORD[value % CROCKFORD.length]).join("");
}

export function publicBookingId(): string {
  return `KPL-${randomCharacters(5)}-${randomCharacters(5)}`;
}

export function opaqueToken(): string {
  return randomToken(32);
}
