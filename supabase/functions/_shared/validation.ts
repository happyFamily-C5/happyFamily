import { ApiError } from "./http.ts";

const allowedBookingKeys = new Set([
  "invocation_token",
  "donor_name",
  "phone",
  "estimated_weight_grams",
  "item_count",
  "items",
  "shipping_method",
  "scan_model_version",
  "terms_version",
  "privacy_version",
]);
const allowedItemKeys = new Set(["ordinal", "passed", "scanner_model_version", "metadata"]);
const forbiddenMetadata = /photo|image|binary|blob|exif|embedding|path|url|history|attempt/i;

export type BookingInput = {
  invocation_token: string;
  donor_name: string;
  phone: string;
  estimated_weight_grams: number;
  item_count: number;
  items: Array<
    {
      ordinal: number;
      passed: true;
      scanner_model_version: string;
      metadata: Record<string, unknown>;
    }
  >;
  shipping_method: "direct" | "ojek_online" | "expedition";
  scan_model_version: string;
  terms_version: string;
  privacy_version: string;
};

/**
 * Input accepted from an authenticated donor account.  Identity is deliberately
 * absent: the Edge Function obtains the name and phone number from the
 * authenticated profile before it encrypts them for the booking record.
 */
export type AccountBookingInput = Omit<
  BookingInput,
  "invocation_token" | "donor_name" | "phone" | "terms_version" | "privacy_version"
>;

function requiredString(value: unknown, field: string, max: number): string {
  if (typeof value !== "string" || value.trim().length < 1 || value.trim().length > max) {
    throw new ApiError("INVALID_REQUEST", 422, false, { [field]: "invalid" });
  }
  return value.trim();
}

function assertSafeMetadata(value: unknown): asserts value is Record<string, unknown> {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new ApiError("INVALID_ITEM_METADATA", 422);
  }
  const encoded = JSON.stringify(value);
  if (new TextEncoder().encode(encoded).byteLength > 2_048) {
    throw new ApiError("INVALID_ITEM_METADATA", 422);
  }
  const visit = (node: unknown): void => {
    if (Array.isArray(node)) return node.forEach(visit);
    if (!node || typeof node !== "object") return;
    for (const [key, nested] of Object.entries(node as Record<string, unknown>)) {
      if (forbiddenMetadata.test(key)) throw new ApiError("PHOTO_DATA_FORBIDDEN", 422);
      visit(nested);
    }
  };
  visit(value);
}

export function validateBooking(body: Record<string, unknown>): BookingInput {
  const unknown = Object.keys(body).filter((key) => !allowedBookingKeys.has(key));
  if (unknown.length > 0) {
    if (unknown.some((key) => forbiddenMetadata.test(key))) {
      throw new ApiError("PHOTO_DATA_FORBIDDEN", 422);
    }
    throw new ApiError("UNKNOWN_FIELD", 422);
  }
  const items = body.items;
  if (!Array.isArray(items) || items.length < 1 || items.length > 100) {
    throw new ApiError("INVALID_ITEMS", 422);
  }
  const validatedItems = items.map((item, index) => {
    if (!item || Array.isArray(item) || typeof item !== "object") {
      throw new ApiError("INVALID_ITEMS", 422);
    }
    const record = item as Record<string, unknown>;
    const itemUnknown = Object.keys(record).filter((key) => !allowedItemKeys.has(key));
    if (itemUnknown.some((key) => forbiddenMetadata.test(key))) {
      throw new ApiError("PHOTO_DATA_FORBIDDEN", 422);
    }
    if (itemUnknown.length > 0 || record.passed !== true) {
      throw new ApiError("ITEM_NOT_PASSED", 422);
    }
    const metadata = record.metadata ?? {};
    assertSafeMetadata(metadata);
    return {
      ordinal: Number.isInteger(record.ordinal) ? Number(record.ordinal) : index,
      passed: true as const,
      scanner_model_version: requiredString(
        record.scanner_model_version,
        "scanner_model_version",
        80,
      ),
      metadata,
    };
  });
  const estimated = Number(body.estimated_weight_grams);
  const itemCount = Number(body.item_count);
  if (!Number.isInteger(estimated) || estimated <= 0 || estimated > 1_000_000) {
    throw new ApiError("ESTIMATED_WEIGHT_INVALID", 422);
  }
  if (!Number.isInteger(itemCount) || itemCount !== validatedItems.length) {
    throw new ApiError("INVALID_ITEMS", 422);
  }
  if (
    body.shipping_method !== "direct" && body.shipping_method !== "ojek_online" &&
    body.shipping_method !== "expedition"
  ) {
    throw new ApiError("SHIPPING_METHOD_INVALID", 422);
  }
  return {
    invocation_token: requiredString(body.invocation_token, "invocation_token", 200),
    donor_name: requiredString(body.donor_name, "donor_name", 160),
    phone: requiredString(body.phone, "phone", 32),
    estimated_weight_grams: estimated,
    item_count: itemCount,
    items: validatedItems,
    shipping_method: body.shipping_method,
    scan_model_version: requiredString(body.scan_model_version, "scan_model_version", 80),
    terms_version: requiredString(body.terms_version, "terms_version", 80),
    privacy_version: requiredString(body.privacy_version, "privacy_version", 80),
  };
}

export function validateAccountBooking(body: Record<string, unknown>): AccountBookingInput {
  const allowed = new Set([
    "estimated_weight_grams",
    "item_count",
    "items",
    "shipping_method",
    "scan_model_version",
  ]);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    if (unknown.some((key) => forbiddenMetadata.test(key))) {
      throw new ApiError("PHOTO_DATA_FORBIDDEN", 422);
    }
    throw new ApiError("UNKNOWN_FIELD", 422);
  }

  // Reuse the legacy item/weight validator without accepting or
  // trusting a donor identity from an authenticated client.
  const validated = validateBooking({
    ...body,
    invocation_token: "account",
    donor_name: "account",
    phone: "+62800000000",
    terms_version: "mvp-not-submitted",
    privacy_version: "mvp-not-submitted",
  });
  const {
    invocation_token: _invocationToken,
    donor_name: _donorName,
    phone: _phone,
    terms_version: _termsVersion,
    privacy_version: _privacyVersion,
    ...booking
  } = validated;
  return booking;
}
