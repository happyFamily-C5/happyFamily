import Foundation

/// Client-side banner validation for `/admin-banner`. The server rejects
/// oversized or wrong-format uploads with 400/403; validating here keeps the
/// draft from being queued offline for an upload that can never succeed and
/// keeps the 400/403 path free of automatic retries.
enum EventBannerPolicy {
    /// The contract allows JPEG/PNG up to 5 MiB.
    static let maximumBytes = 5 * 1024 * 1024

    static func validate(_ data: Data?) throws {
        guard let data, !data.isEmpty else { return }
        guard isSupportedFormat(data) else {
            throw BackendError.api(
                code: "BANNER_REJECTED",
                retryable: false,
                fieldErrors: [:],
                requestId: nil
            )
        }
        guard data.count <= maximumBytes else {
            throw BackendError.api(
                code: "BANNER_TOO_LARGE",
                retryable: false,
                fieldErrors: [:],
                requestId: nil
            )
        }
    }

    static func isSupportedFormat(_ data: Data) -> Bool {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47]) // PNG magic
            || data.starts(with: [0xFF, 0xD8]) // JPEG magic
    }
}
