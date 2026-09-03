import { requireEnv } from "./env.ts";
import { ApiError } from "./http.ts";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(
    value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
      Math.ceil(value.length / 4) * 4,
      "=",
    ),
  );
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

export function base64Url(bytes: Uint8Array): string {
  return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export function randomToken(size = 32): string {
  return base64Url(crypto.getRandomValues(new Uint8Array(size)));
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function importHmacKey(name: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    base64ToBytes(requireEnv(name)),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export async function hmacHex(value: string, keyName = "PII_HMAC_KEY_BASE64"): Promise<string> {
  const signature = await crypto.subtle.sign(
    "HMAC",
    await importHmacKey(keyName),
    encoder.encode(value),
  );
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function activeEncryptionKeyVersion(): number {
  const version = Number(Deno.env.get("TOKEN_KEY_VERSION") ?? "1");
  if (!Number.isInteger(version) || version < 1 || version > 32_767) {
    throw new ApiError("SERVER_MISCONFIGURED", 500);
  }
  return version;
}

function encryptionKeyMaterial(version: number): string {
  const encodedKeyring = Deno.env.get("PII_ENCRYPTION_KEYS_JSON")?.trim();
  if (encodedKeyring) {
    try {
      const keyring = JSON.parse(encodedKeyring) as unknown;
      if (!keyring || Array.isArray(keyring) || typeof keyring !== "object") {
        throw new Error("invalid keyring");
      }
      const value = (keyring as Record<string, unknown>)[String(version)];
      if (typeof value === "string" && value.trim()) return value.trim();
      throw new ApiError("PROTECTED_DATA_UNAVAILABLE", 500);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError("SERVER_MISCONFIGURED", 500);
    }
  }
  if (version !== activeEncryptionKeyVersion()) {
    throw new ApiError("PROTECTED_DATA_UNAVAILABLE", 500);
  }
  return requireEnv("PII_ENCRYPTION_KEY_BASE64");
}

async function encryptionKey(version: number): Promise<CryptoKey> {
  const raw = base64ToBytes(encryptionKeyMaterial(version));
  if (raw.byteLength !== 32) throw new ApiError("SERVER_MISCONFIGURED", 500);
  return await crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function encrypt(
  value: string,
  keyVersion = activeEncryptionKeyVersion(),
): Promise<{ ciphertext: string; nonce: string; keyVersion: number }> {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce },
    await encryptionKey(keyVersion),
    encoder.encode(value),
  );
  return {
    ciphertext: base64Url(new Uint8Array(encrypted)),
    nonce: base64Url(nonce),
    keyVersion,
  };
}

export async function decrypt(
  ciphertext: string,
  nonce: string,
  keyVersion = activeEncryptionKeyVersion(),
): Promise<string> {
  try {
    const decrypted = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: base64ToBytes(nonce) },
      await encryptionKey(keyVersion),
      base64ToBytes(ciphertext),
    );
    return decoder.decode(decrypted);
  } catch {
    throw new ApiError("PROTECTED_DATA_UNAVAILABLE", 500, false);
  }
}

function canonicalValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, nested]) => [key, canonicalValue(nested)]),
    );
  }
  return value;
}

export function canonicalJson(value: unknown): string {
  return JSON.stringify(canonicalValue(value));
}

type DonorClaims = { v: 1; sub: string; exp: number };

export async function createDonorToken(bookingId: string, ttlSeconds = 600): Promise<string> {
  const payload: DonorClaims = {
    v: 1,
    sub: bookingId,
    exp: Math.floor(Date.now() / 1000) + ttlSeconds,
  };
  const encoded = base64Url(encoder.encode(JSON.stringify(payload)));
  const signature = await crypto.subtle.sign(
    "HMAC",
    await importHmacKey("DONOR_ACCESS_SIGNING_KEY_BASE64"),
    encoder.encode(encoded),
  );
  return `${encoded}.${base64Url(new Uint8Array(signature))}`;
}

export async function verifyDonorToken(token: string): Promise<DonorClaims> {
  const [payload, signature, extra] = token.split(".");
  if (!payload || !signature || extra) throw new ApiError("DONOR_TOKEN_INVALID", 401);
  const valid = await crypto.subtle.verify(
    "HMAC",
    await importHmacKey("DONOR_ACCESS_SIGNING_KEY_BASE64"),
    base64ToBytes(signature),
    encoder.encode(payload),
  );
  if (!valid) throw new ApiError("DONOR_TOKEN_INVALID", 401);
  try {
    const claims = JSON.parse(decoder.decode(base64ToBytes(payload))) as DonorClaims;
    if (claims.v !== 1 || !claims.sub || claims.exp <= Math.floor(Date.now() / 1000)) {
      throw new ApiError("DONOR_TOKEN_EXPIRED", 401);
    }
    return claims;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError("DONOR_TOKEN_INVALID", 401);
  }
}
