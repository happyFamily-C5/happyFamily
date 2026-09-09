import { ApiError } from "./http.ts";

export const MAX_BANNER_BYTES = 5 * 1024 * 1024;
export const MAX_BANNER_DIMENSION = 4096;

export type ValidatedBannerImage = {
  contentType: "image/jpeg" | "image/png";
  extension: "jpg" | "png";
  width: number;
  height: number;
};

const jpegStartOfFrameMarkers = new Set([
  0xc0,
  0xc1,
  0xc2,
  0xc3,
  0xc5,
  0xc6,
  0xc7,
  0xc9,
  0xca,
  0xcb,
  0xcd,
  0xce,
  0xcf,
]);

function readUint32(bytes: Uint8Array, offset: number): number {
  return new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(offset, false);
}

function pngDimensions(bytes: Uint8Array): { width: number; height: number } | null {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 24 || !signature.every((value, index) => bytes[index] === value)) {
    return null;
  }
  const isIHDR = bytes[12] === 0x49 && bytes[13] === 0x48 && bytes[14] === 0x44 &&
    bytes[15] === 0x52;
  if (!isIHDR || readUint32(bytes, 8) !== 13) throw new ApiError("BANNER_MALFORMED", 422);
  return { width: readUint32(bytes, 16), height: readUint32(bytes, 20) };
}

function jpegDimensions(bytes: Uint8Array): { width: number; height: number } | null {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null;
  let offset = 2;
  while (offset < bytes.length) {
    while (offset < bytes.length && bytes[offset] === 0xff) offset += 1;
    if (offset >= bytes.length) break;
    const marker = bytes[offset];
    offset += 1;
    if (marker === 0xd9 || marker === 0xda) break;
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (offset + 1 >= bytes.length) throw new ApiError("BANNER_MALFORMED", 422);
    const segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) {
      throw new ApiError("BANNER_MALFORMED", 422);
    }
    if (jpegStartOfFrameMarkers.has(marker)) {
      if (segmentLength < 7) throw new ApiError("BANNER_MALFORMED", 422);
      return {
        height: (bytes[offset + 3] << 8) | bytes[offset + 4],
        width: (bytes[offset + 5] << 8) | bytes[offset + 6],
      };
    }
    offset += segmentLength;
  }
  throw new ApiError("BANNER_MALFORMED", 422);
}

export function validateBannerImage(
  bytes: Uint8Array,
  declaredContentType = "",
): ValidatedBannerImage {
  if (bytes.length === 0) throw new ApiError("BANNER_REQUIRED", 422);
  if (bytes.length > MAX_BANNER_BYTES) throw new ApiError("BANNER_TOO_LARGE", 413);

  const png = pngDimensions(bytes);
  const jpeg = png ? null : jpegDimensions(bytes);
  const actual = png
    ? { ...png, contentType: "image/png" as const, extension: "png" as const }
    : jpeg
    ? { ...jpeg, contentType: "image/jpeg" as const, extension: "jpg" as const }
    : null;
  if (!actual) throw new ApiError("BANNER_TYPE_INVALID", 422);

  const normalizedDeclared = declaredContentType.toLowerCase().split(";", 1)[0].trim();
  if (normalizedDeclared && normalizedDeclared !== actual.contentType) {
    throw new ApiError("BANNER_CONTENT_TYPE_MISMATCH", 422);
  }
  if (
    actual.width < 1 || actual.height < 1 || actual.width > MAX_BANNER_DIMENSION ||
    actual.height > MAX_BANNER_DIMENSION
  ) {
    throw new ApiError("BANNER_DIMENSIONS_INVALID", 422);
  }
  return actual;
}
