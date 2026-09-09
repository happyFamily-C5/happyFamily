import Foundation
import UIKit

/// Direct Storage REST access for workspace media and donor avatars. Uploads
/// bypass the edge function: buckets carry dedicated RLS policies so the
/// user's own JWT authorizes the object write.
struct StorageMediaClient: Sendable {
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
            ownerPath: workspaceId.uuidString
        )
    }

    /// Uploads the donor avatar to the private `profile-avatars` bucket at
    /// `<userId>/<uuid>.<ext>` (the contract requires the donor's own upload)
    /// and returns the bucket-relative object path.
    func uploadProfileAvatar(data: Data, userId: UUID) async throws -> String {
        try await uploadImage(
            data: data,
            bucket: "profile-avatars",
            ownerPath: userId.uuidString
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
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        let (_, response) = try await execute(request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            if http.statusCode == 400 || http.statusCode == 403 {
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
    private static func normalizedImage(data: Data) throws -> (Data, String) {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return (data, "image/png")
        }
        if data.starts(with: [0xFF, 0xD8]) {
            return (data, "image/jpeg")
        }
        guard let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.9) else {
            throw BackendError.api(
                code: "PROFILE_MEDIA_REJECTED",
                retryable: false,
                fieldErrors: [:],
                requestId: nil
            )
        }
        return (jpeg, "image/jpeg")
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}
