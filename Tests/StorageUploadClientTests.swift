import Foundation
@testable import happyFamily
import Testing

@Suite("Workspace storage media client", .serialized)
struct StorageUploadClientTests {
    @Test("uploadWorkspaceLogo posts the PNG to the workspace-logos object path")
    func uploadLogoPostsObjectPath() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            return try (response(for: request, status: 200), Data("{}".utf8))
        }
        let workspaceId = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!

        let path = try await makeStorageClient().uploadWorkspaceLogo(
            data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
            workspaceId: workspaceId
        )

        let request = try #require(recorder.snapshot().first)
        let expectedOwner = workspaceId.uuidString.lowercased()
        #expect(request.method == "POST")
        #expect(
            request.url?.path.hasPrefix(
                "/storage/v1/object/workspace-logos/\(expectedOwner)/"
            ) == true
        )
        #expect(request.url?.path.hasSuffix(".png") == true)
        #expect(request.authorization == "Bearer access-token")
        #expect(request.apiKey == "publishable-test-key")
        #expect(request.contentType == "image/png")
        #expect(path.hasPrefix("\(expectedOwner)/"))
        #expect(path.hasSuffix(".png"))
    }

    @Test("uploadProfileAvatar uses the lowercase user ID required by Storage RLS")
    func uploadAvatarUsesLowercaseOwnerPath() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            return try (response(for: request, status: 200), Data("{}".utf8))
        }
        let userId = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!

        let path = try await makeStorageClient().uploadProfileAvatar(
            data: Data([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x00]),
            userId: userId
        )

        let request = try #require(recorder.snapshot().first)
        let expectedOwner = userId.uuidString.lowercased()
        #expect(
            request.url?.path.hasPrefix(
                "/storage/v1/object/profile-avatars/\(expectedOwner)/"
            ) == true
        )
        #expect(request.url?.path.hasSuffix(".jpg") == true)
        #expect(request.contentType == "image/jpeg")
        #expect(path.hasPrefix("\(expectedOwner)/"))
        #expect(path.hasSuffix(".jpg"))
    }

    @Test("normalizes a JPEG with the EXIF marker as image/jpeg")
    func jpegWithExifMarkerUsesJpegContentType() throws {
        let (payload, contentType) = try StorageMediaClient.normalizedImage(
            data: Data([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x00])
        )

        #expect(payload.starts(with: [0xFF, 0xD8]))
        #expect(contentType == "image/jpeg")
    }

    @Test("workspace logo permission rejection maps to PROFILE_MEDIA_FORBIDDEN without retry")
    func logoPermissionRejectionMapsToProfileMediaForbidden() async {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "error": "new row violates row-level security policy",
            ])
            return try (response(for: request, status: 403), data)
        }

        await #expect {
            try await makeStorageClient().uploadWorkspaceLogo(
                data: Data([0x89, 0x50, 0x4E, 0x47, 0x01]),
                workspaceId: UUID()
            )
        } throws: { error in
            guard case let BackendError.api(code, retryable, _, _) = error else {
                return false
            }
            return code == "PROFILE_MEDIA_FORBIDDEN" && !retryable
        }
    }

    @Test("workspace logo RLS denial with HTTP 400 maps to PROFILE_MEDIA_FORBIDDEN")
    func logoRLS400MapsToProfileMediaForbidden() async {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "error": "new row violates row-level security policy",
            ])
            return try (response(for: request, status: 400), data)
        }

        await #expect {
            try await makeStorageClient().uploadWorkspaceLogo(
                data: Data([0x89, 0x50, 0x4E, 0x47, 0x01]),
                workspaceId: UUID()
            )
        } throws: { error in
            guard case let BackendError.api(code, retryable, _, _) = error else {
                return false
            }
            return code == "PROFILE_MEDIA_FORBIDDEN" && !retryable
        }
    }
}

private func makeStorageClient() -> StorageMediaClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    let environment = BackendEnvironment(
        baseURL: URL(string: "https://api.example.invalid")!,
        publishableKey: "publishable-test-key",
        deployment: .staging
    )
    return StorageMediaClient(
        environment: environment,
        session: URLSession(configuration: configuration)
    ) {
        "access-token"
    }
}

// MARK: - Harness (file-local copies, mirroring OrganizerOperationsClientTests)

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler:
        (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [RecordedRequest] = []

    func record(_ request: URLRequest) {
        lock.withLock {
            requests.append(RecordedRequest(
                url: request.url,
                method: request.httpMethod,
                idempotencyKey: request.value(forHTTPHeaderField: "Idempotency-Key"),
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                apiKey: request.value(forHTTPHeaderField: "apikey"),
                contentType: request.value(forHTTPHeaderField: "Content-Type"),
                rawBody: requestBody(request)
            ))
        }
    }

    func snapshot() -> [RecordedRequest] {
        lock.withLock { requests }
    }
}

private struct RecordedRequest: Sendable {
    let url: URL?
    let method: String?
    let idempotencyKey: String?
    let authorization: String?
    let apiKey: String?
    let contentType: String?
    let rawBody: Data?
}

private func requestBody(_ request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 {
            return nil
        }
        if count == 0 {
            break
        }
        data.append(buffer, count: count)
    }
    return data
}

private func response(for request: URLRequest, status: Int) throws -> HTTPURLResponse {
    guard let url = request.url,
          let response = HTTPURLResponse(
              url: url,
              statusCode: status,
              httpVersion: nil,
              headerFields: ["Content-Type": "application/json"]
          )
    else { throw URLError(.badServerResponse) }
    return response
}
