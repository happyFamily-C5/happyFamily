import Foundation
import ImageIO
import UIKit

struct PreparedEventBanner: Sendable, Equatable {
    let data: Data
    let contentType: String
    let width: Int
    let height: Int
}

/// Client-side preparation for `/admin-banner`. The server remains the final
/// validator, while this boundary ensures a draft never enters the offline
/// queue with banner bytes the server cannot accept.
enum EventBannerPolicy {
    static let maximumBytes = 5 * 1024 * 1024
    static let maximumDimension = 4096

    /// Converts an unsupported, oversized, or over-dimension image into a
    /// valid JPEG. A JPEG/PNG that already satisfies the contract is kept
    /// byte-for-byte to avoid an unnecessary quality loss.
    static func prepareForUpload(_ data: Data?) async throws -> PreparedEventBanner? {
        guard let data, !data.isEmpty else { return nil }
        return try await Task.detached(priority: .userInitiated) {
            try prepareSynchronously(data)
        }.value
    }

    /// Kept for callers that only need the legacy, lightweight format/size
    /// check. Event drafts use `prepareForUpload(_:)` before they are queued.
    static func validate(_ data: Data?) throws {
        guard let data, !data.isEmpty else { return }
        guard isSupportedFormat(data) else { throw rejectedError }
        guard data.count <= maximumBytes else { throw tooLargeError }
    }

    static func isSupportedFormat(_ data: Data) -> Bool {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47]) // PNG magic
            || data.starts(with: [0xFF, 0xD8]) // JPEG magic
    }

    private static func prepareSynchronously(_ data: Data) throws -> PreparedEventBanner {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw data.count > maximumBytes ? tooLargeError : rejectedError
        }
        guard let dimensions = sourceDimensions(source) else {
            throw data.count > maximumBytes ? tooLargeError : rejectedError
        }

        let isWithinServerLimits = data.count <= maximumBytes
            && dimensions.width <= maximumDimension
            && dimensions.height <= maximumDimension
        if isSupportedFormat(data), isWithinServerLimits {
            return PreparedEventBanner(
                data: data,
                contentType: data.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg",
                width: dimensions.width,
                height: dimensions.height
            )
        }

        for targetDimension in [maximumDimension, 3072, 2048, 1536] {
            guard let thumbnail = thumbnail(from: source, maximumDimension: targetDimension) else {
                continue
            }
            let rendered = renderedJPEGImage(from: thumbnail)
            for quality in [CGFloat(0.85), 0.70, 0.55, 0.40] {
                guard let jpeg = rendered.jpegData(compressionQuality: quality),
                      jpeg.count <= maximumBytes
                else {
                    continue
                }
                return PreparedEventBanner(
                    data: jpeg,
                    contentType: "image/jpeg",
                    width: thumbnail.width,
                    height: thumbnail.height
                )
            }
        }

        throw tooLargeError
    }

    private static func sourceDimensions(_ source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0,
              height > 0
        else {
            return nil
        }
        return (width, height)
    }

    private static func thumbnail(
        from source: CGImageSource,
        maximumDimension: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func renderedJPEGImage(from image: CGImage) -> UIImage {
        let size = CGSize(width: image.width, height: image.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static var rejectedError: BackendError {
        .api(code: "BANNER_REJECTED", retryable: false, fieldErrors: [:], requestId: nil)
    }

    private static var tooLargeError: BackendError {
        .api(code: "BANNER_TOO_LARGE", retryable: false, fieldErrors: [:], requestId: nil)
    }
}
