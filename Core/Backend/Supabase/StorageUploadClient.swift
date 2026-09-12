import Foundation
import UIKit

/// Direct Storage REST access for workspace media and donor avatars. Uploads
/// bypass the edge function: buckets carry dedicated RLS policies so the
/// user's own JWT authorizes the object write.
struct StorageMediaClient: Sendable {
    /// Kept below the Storage bucket's 5 MiB limit to leave room for any
    /// transport processing and avoid a valid, but oversized, JPEG being
    /// reported as a format error by the service.
    private static let maximumUploadBytes = 4_500_000
    let environment: BackendEnvironment
    let session: URLSession
    let accessToken: @Sendable () async throws -> String

    init(
        environment: BackendEnvironment,
        session: URLSession = StorageMediaClient.makeSession(),
        accessToken: @escaping @Sendable () async throws -> String
    ) {
        self.environment = environment
        self.session = session
        self.accessToken = accessToken
    }

    /// POST {base}/storage/v1/object/workspace-logos/<workspaceId>/<uuid>.<ext>
    /// with apikey + Bearer + the matched image content type. Returns the
    /// bucket-relative object path. 400/403 map to `PROFILE_MEDIA_REJECTED`
    /// (never retried).
    func uploadWorkspaceLogo(data: Data, workspaceId: UUID) async throws -> String {
        try await uploadImage(
            data: data,
            bucket: "workspace-logos",
            ownerPath: workspaceId.uuidString.lowercased()
        )
    }

    /// Uploads the donor avatar to the private `profile-avatars` bucket at
    /// `<userId>/<uuid>.<ext>` (the contract requires the donor's own upload)
    /// and returns the bucket-relative object path.
    func uploadProfileAvatar(data: Data, userId: UUID) async throws -> String {
        try await uploadImage(
            data: data,
            bucket: "profile-avatars",
            ownerPath: userId.uuidString.lowercased()
        )
    }

    /// GET {base}/storage/v1/object/public/<bucket>/<path>; nil on any
    /// failure — media display is cosmetic and must never block bootstrap.
    func fetchPublicObject(bucket: String, path: String) async -> Data? {
        guard !bucket.isEmpty, !path.isEmpty else { return nil }
        let url = environment.baseURL
            .appending(path: "storage/v1/object/public/\(bucket)", directoryHint: .isDirectory)
            .appending(path: path)
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        guard let (data, response) = try? await execute(request),
              let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode),
              !data.isEmpty else {
            return nil
        }
        return data
    }

    private func uploadImage(data: Data, bucket: String, ownerPath: String) async throws -> String {
        let (payload, contentType) = try Self.normalizedImage(data: data)
        let fileExtension = contentType == "image/png" ? "png" : "jpg"
        let objectPath = "\(ownerPath)/\(UUID().uuidString.lowercased()).\(fileExtension)"
        var request = URLRequest(
            url: environment.baseURL
                .appending(path: "storage/v1/object/\(bucket)", directoryHint: .isDirectory)
                .appending(path: objectPath)
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(environment.publishableKey, forHTTPHeaderField: "apikey")
        let token = try await accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        let (responseData, response) = try await execute(request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            if http.statusCode == 413 || Self.storageFailureIsTooLarge(responseData) {
                throw BackendError.api(
                    code: "PROFILE_MEDIA_TOO_LARGE",
                    retryable: false,
                    fieldErrors: [:],
                    requestId: nil
                )
            }
            if http.statusCode == 403 || Self.storageFailureIsPermissionDenied(responseData) {
                throw BackendError.api(
                    code: "PROFILE_MEDIA_FORBIDDEN",
                    retryable: false,
                    fieldErrors: [:],
                    requestId: nil
                )
            }
            if http.statusCode == 400 {
                throw BackendError.api(
                    code: "PROFILE_MEDIA_REJECTED",
                    retryable: false,
                    fieldErrors: [:],
                    requestId: nil
                )
            }
            throw BackendError.invalidResponse
        }
        return objectPath
    }

    /// Storage can report an RLS denial as either 400 or 403. Its body is
    /// intentionally used only to classify the user-facing error; it is never
    /// displayed, because it may contain implementation details.
    private static func storageFailureIsPermissionDenied(_ data: Data) -> Bool {
        let message = storageFailureMessage(data)
        return message.contains("row-level security")
            || message.contains("permission denied")
            || message.contains("not authorized")
    }

    private static func storageFailureIsTooLarge(_ data: Data) -> Bool {
        let message = storageFailureMessage(data)
        return message.contains("too large") || message.contains("file size")
    }

    private static func storageFailureMessage(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let body = object as? [String: Any] else {
            return String(bytes: data, encoding: .utf8)?.lowercased() ?? ""
        }
        return ["error", "message"]
            .compactMap { body[$0] as? String }
            .joined(separator: " ")
            .lowercased()
    }

    private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            throw BackendError.transport(String(error.code.rawValue))
        } catch {
            throw BackendError.transport(String(describing: error))
        }
    }

    /// PNG/JPEG pass through; anything else (e.g. HEIC from PhotosPicker)
    /// is re-encoded as JPEG so the bytes match the declared content type.
    static func normalizedImage(data: Data) throws -> (Data, String) {
        if data.count <= maximumUploadBytes,
           data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return (data, "image/png")
        }
        if data.count <= maximumUploadBytes,
           data.starts(with: [0xFF, 0xD8]) {
            return (data, "image/jpeg")
        }
        guard let image = UIImage(data: data),
              let jpeg = compressedJPEG(image) else {
            throw BackendError.api(
                code: "PROFILE_MEDIA_REJECTED",
                retryable: false,
                fieldErrors: [:],
                requestId: nil
            )
        }
        return (jpeg, "image/jpeg")
    }

    private static func compressedJPEG(_ image: UIImage) -> Data? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let largestSide = max(sourceSize.width, sourceSize.height)
        let scale = min(1, CGFloat(2_048) / largestSide)
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded(.down)),
            height: max(1, (sourceSize.height * scale).rounded(.down))
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        for quality in [CGFloat(0.85), 0.7, 0.55] {
            if let data = rendered.jpegData(compressionQuality: quality),
               data.count <= maximumUploadBytes {
                return data
            }
        }
        return nil
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}
