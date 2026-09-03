import {
  canonicalJson,
  createDonorToken,
  decrypt,
  encrypt,
  sha256Hex,
  verifyDonorToken,
} from "../_shared/crypto.ts";
import { MAX_BANNER_BYTES, validateBannerImage } from "../_shared/banner-image.ts";
import { csvCell, csvLine } from "../_shared/csv.ts";
import { publicBookingEnabled } from "../_shared/env.ts";
import { ApiError, readJson } from "../_shared/http.ts";
import { normalizeIndonesianPhone } from "../_shared/phone.ts";
import { validateBooking } from "../_shared/validation.ts";

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`);
  }
}

async function assertRejectsCode(
  operation: () => unknown | Promise<unknown>,
  code: string,
): Promise<void> {
  try {
    await operation();
  } catch (error) {
    assert(error instanceof ApiError, "expected ApiError");
    assertEquals(error.code, code);
    return;
  }
  throw new Error(`expected ${code} rejection`);
}

function booking(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    invocation_token: "i".repeat(43),
    donor_name: "Donor Test",
    phone: "0812 3456 7890",
    estimated_weight_grams: 1_000,
    item_count: 1,
    items: [{
      ordinal: 0,
      passed: true,
      scanner_model_version: "test-model-v1",
      metadata: { category: "shirt" },
    }],
    shipping_method: "direct",
    scan_model_version: "test-model-v1",
    terms_version: "2026-09-test",
    privacy_version: "2026-09-test",
    ...overrides,
  };
}

function pngHeader(width: number, height: number): Uint8Array {
  const bytes = new Uint8Array(24);
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  new DataView(bytes.buffer).setUint32(8, 13, false);
  bytes.set([0x49, 0x48, 0x44, 0x52], 12);
  new DataView(bytes.buffer).setUint32(16, width, false);
  new DataView(bytes.buffer).setUint32(20, height, false);
  return bytes;
}

Deno.test("normalizes Indonesian mobile numbers to E.164", () => {
  assertEquals(normalizeIndonesianPhone("0812-3456-7890"), "+6281234567890");
  assertEquals(normalizeIndonesianPhone("+62 812 3456 7890"), "+6281234567890");
  assertEquals(normalizeIndonesianPhone("81234567890"), "+6281234567890");
});

Deno.test("rejects non-Indonesian or malformed phone numbers", async () => {
  await assertRejectsCode(() => normalizeIndonesianPhone("+1 202 555 0112"), "PHONE_INVALID");
  await assertRejectsCode(() => normalizeIndonesianPhone("0215551234"), "PHONE_INVALID");
});

Deno.test("canonical JSON and hash are stable across object key order", async () => {
  const left = canonicalJson({ b: 2, nested: { y: true, x: "value" }, a: 1 });
  const right = canonicalJson({ a: 1, nested: { x: "value", y: true }, b: 2 });
  assertEquals(left, right);
  assertEquals(await sha256Hex(left), await sha256Hex(right));
});

Deno.test("AES-GCM encrypts and decrypts protected donor data", async () => {
  Deno.env.set("PII_ENCRYPTION_KEY_BASE64", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=");
  Deno.env.set("TOKEN_KEY_VERSION", "1");
  const protectedValue = await encrypt("Donor Test +6281234567890");
  assert(protectedValue.ciphertext !== "Donor Test +6281234567890");
  assertEquals(protectedValue.keyVersion, 1);
  assertEquals(
    await decrypt(protectedValue.ciphertext, protectedValue.nonce, protectedValue.keyVersion),
    "Donor Test +6281234567890",
  );
});

Deno.test("AES-GCM keyring decrypts data written by a previous key version", async () => {
  Deno.env.set(
    "PII_ENCRYPTION_KEYS_JSON",
    JSON.stringify({
      1: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
      2: "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=",
    }),
  );
  Deno.env.set("TOKEN_KEY_VERSION", "1");
  const oldValue = await encrypt("Donor before rotation");
  Deno.env.set("TOKEN_KEY_VERSION", "2");
  const currentValue = await encrypt("Donor after rotation");

  assertEquals(oldValue.keyVersion, 1);
  assertEquals(currentValue.keyVersion, 2);
  assertEquals(
    await decrypt(oldValue.ciphertext, oldValue.nonce, oldValue.keyVersion),
    "Donor before rotation",
  );
  assertEquals(
    await decrypt(currentValue.ciphertext, currentValue.nonce, currentValue.keyVersion),
    "Donor after rotation",
  );
  await assertRejectsCode(
    () => decrypt(oldValue.ciphertext, oldValue.nonce, 3),
    "PROTECTED_DATA_UNAVAILABLE",
  );

  Deno.env.delete("PII_ENCRYPTION_KEYS_JSON");
  Deno.env.set("TOKEN_KEY_VERSION", "1");
});

Deno.test("donor token is scoped to one booking and rejects tampering or expiry", async () => {
  Deno.env.set("DONOR_ACCESS_SIGNING_KEY_BASE64", "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=");
  const token = await createDonorToken("11111111-1111-4111-8111-111111111111");
  const claims = await verifyDonorToken(token);
  assertEquals(claims.sub, "11111111-1111-4111-8111-111111111111");
  await assertRejectsCode(() => verifyDonorToken(`${token}x`), "DONOR_TOKEN_INVALID");
  await assertRejectsCode(
    async () =>
      verifyDonorToken(await createDonorToken("11111111-1111-4111-8111-111111111111", -1)),
    "DONOR_TOKEN_EXPIRED",
  );
});

Deno.test("JSON boundary rejects malformed, oversized, and wrong-content requests", async () => {
  await assertRejectsCode(
    () =>
      readJson(
        new Request("https://example.invalid", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: "{",
        }),
      ),
    "MALFORMED_JSON",
  );
  await assertRejectsCode(
    () =>
      readJson(
        new Request("https://example.invalid", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ value: "x".repeat(33_000) }),
        }),
      ),
    "PAYLOAD_TOO_LARGE",
  );
  await assertRejectsCode(
    () =>
      readJson(
        new Request("https://example.invalid", {
          method: "POST",
          headers: { "content-type": "text/plain" },
          body: "{}",
        }),
      ),
    "CONTENT_TYPE_REQUIRED",
  );
});

Deno.test("public booking kill switch defaults safe to its configured value", () => {
  Deno.env.set("PUBLIC_BOOKING_ENABLED", "false");
  assertEquals(publicBookingEnabled(), false);
  Deno.env.set("PUBLIC_BOOKING_ENABLED", "true");
  assertEquals(publicBookingEnabled(), true);
});

Deno.test("booking validation accepts only final scan metadata", () => {
  const result = validateBooking(booking({ donor_name: "Dewi 👗" }));
  assertEquals(result.donor_name, "Dewi 👗");
  assertEquals(result.items[0].metadata, { category: "shirt" });
});

Deno.test("booking validation rejects photos, paths, embeddings, and scan history", async () => {
  await assertRejectsCode(
    () => validateBooking(booking({ photo: "base64" })),
    "PHOTO_DATA_FORBIDDEN",
  );
  await assertRejectsCode(
    () =>
      validateBooking(booking({
        items: [{
          ordinal: 0,
          passed: true,
          scanner_model_version: "test-model-v1",
          metadata: { nested: { exif: { latitude: -6.2 } } },
        }],
      })),
    "PHOTO_DATA_FORBIDDEN",
  );
  await assertRejectsCode(
    () =>
      validateBooking(booking({
        items: [{
          ordinal: 0,
          passed: true,
          scanner_model_version: "test-model-v1",
          metadata: { attempt_history: ["failed", "passed"] },
        }],
      })),
    "PHOTO_DATA_FORBIDDEN",
  );
});

Deno.test("booking validation rejects unknown fields", async () => {
  await assertRejectsCode(
    () => validateBooking(booking({ marketing_opt_in: true })),
    "UNKNOWN_FIELD",
  );
});

Deno.test("CSV output is RFC 4180 compatible and neutralizes formulas", () => {
  assertEquals(csvCell('a"b'), '"a""b"');
  assertEquals(
    csvCell('=HYPERLINK("https://example.invalid")'),
    '"\'=HYPERLINK(""https://example.invalid"")"',
  );
  assertEquals(csvLine(["normal", "+SUM(1,2)", null]), '"normal","\'+SUM(1,2)",');
});

Deno.test("banner validation sniffs PNG bytes and accepts the dimension boundary", () => {
  assertEquals(validateBannerImage(pngHeader(4096, 4096), "image/png"), {
    width: 4096,
    height: 4096,
    contentType: "image/png",
    extension: "png",
  });
});

Deno.test("banner validation rejects dimensions over 4096 pixels", async () => {
  await assertRejectsCode(
    () => validateBannerImage(pngHeader(4097, 100), "image/png"),
    "BANNER_DIMENSIONS_INVALID",
  );
});

Deno.test("banner validation rejects MIME spoofing", async () => {
  await assertRejectsCode(
    () => validateBannerImage(pngHeader(640, 480), "image/jpeg"),
    "BANNER_CONTENT_TYPE_MISMATCH",
  );
});

Deno.test("banner validation enforces the five MiB byte limit", async () => {
  const oversized = new Uint8Array(MAX_BANNER_BYTES + 1);
  await assertRejectsCode(() => validateBannerImage(oversized), "BANNER_TOO_LARGE");
});
