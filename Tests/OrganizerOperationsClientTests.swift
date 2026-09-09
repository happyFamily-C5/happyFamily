import Foundation
@testable import happyFamily
import Testing

@Suite("Organizer operations edge client", .serialized)
struct OrganizerOperationsClientTests {
    @Test("upsertEventDraft posts the operations envelope body")
    func upsertEventDraftPostsOperationsBody() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": eventRecordJSON(),
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }
        let eventId = UUID()
        let mutationId = UUID()
        let payload = EventDraftPayload(event: adminEventFixture(id: eventId, limitKg: 1))

        let record = try await makeClient().upsertEventDraft(
            eventId: eventId,
            mutationId: mutationId,
            payload: payload
        )

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/operations")
        #expect(request.authorization == "Bearer access-token")

        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "upsert_event_draft")
        #expect(UUID(uuidString: json["event_id"] as? String ?? "") == eventId)
        #expect(UUID(uuidString: json["mutation_id"] as? String ?? "") == mutationId)
        let payloadJSON = try #require(json["payload"] as? [String: Any])
        #expect(payloadJSON["max_donation_per_user_grams"] as? Int64 == 1_000)
        #expect(payloadJSON["receiver_name"] == nil)
        #expect(payloadJSON["receiver_phone"] == nil)
        #expect(payloadJSON["receiver_address"] == nil)

        #expect(record.id == UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"))
        #expect(record.maxDonationPerUserGrams == 1_000)
        #expect(record.status == .draft)
    }

    @Test("cancelOrDeleteEvent carries the required idempotency header")
    func cancelOrDeleteEventSendsIdempotencyKey() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "event_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                    "action": "draft_deleted",
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }
        let eventId = UUID()

        let data = try await makeClient().cancelOrDeleteEvent(eventId: eventId)

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/operations")
        #expect(request.idempotencyKey == "cancel-delete-\(eventId.uuidString)")
        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "cancel_or_delete_event")
        #expect(UUID(uuidString: json["event_id"] as? String ?? "") == eventId)
        #expect(data.eventId == UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"))
        #expect(data.action == "draft_deleted")
        #expect(data.status == nil)
    }

    @Test("cancelOrDeleteEvent decodes the cancelled-event shape")
    func cancelOrDeleteEventDecodesCancelledShape() async throws {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "event_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                    "status": "cancelled",
                    "cancelled_waiting_bookings": 3,
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let data = try await makeClient().cancelOrDeleteEvent(eventId: UUID())

        #expect(data.status == .cancelled)
        #expect(data.cancelledWaitingBookings == 3)
        #expect(data.action == nil)
    }

    @Test("uploadEventBanner posts multipart to admin-banner and accepts 201")
    func uploadEventBannerPostsMultipart() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "object_path": "workspace-id/banner-uuid/banner.png",
                    "content_type": "image/png",
                    "width": 1200,
                    "height": 400,
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 201), data)
        }

        let uploaded = try await makeClient().uploadEventBanner(
            data: Data([0x89, 0x50, 0x4E, 0x47, 0x01]),
            contentType: "image/png"
        )

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/admin-banner")
        let body = try #require(request.rawBody)
        #expect(String(decoding: body, as: UTF8.self).contains("name=\"file\""))
        #expect(uploaded.objectPath == "workspace-id/banner-uuid/banner.png")
        #expect(uploaded.width == 1200)
        #expect(uploaded.height == 400)
    }

    @Test("Conflict envelope maps to a stable backend error")
    func conflictEnvelopeThrowsApiError() async {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": NSNull(),
                "error": [
                    "code": "IDEMPOTENCY_CONFLICT",
                    "retryable": false,
                ],
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 409), data)
        }

        await #expect {
            try await makeClient().cancelOrDeleteEvent(eventId: UUID())
        } throws: { error in
            guard case let BackendError.api(code, retryable, _, _) = error else {
                return false
            }
            return code == "IDEMPOTENCY_CONFLICT" && !retryable
        }
    }
}

// MARK: - Harness

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
                idempotencyKey: request.value(forHTTPHeaderField: "Idempotency-Key"),
                authorization: request.value(forHTTPHeaderField: "Authorization"),
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
    let idempotencyKey: String?
    let authorization: String?
    let rawBody: Data?

    var jsonBody: [String: Any]? {
        guard let rawBody else { return nil }
        return (try? JSONSerialization.jsonObject(with: rawBody)) as? [String: Any]
    }
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

private func makeClient() -> OrganizerBackendHTTPClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    let environment = BackendEnvironment(
        baseURL: URL(string: "https://api.example.invalid")!,
        publishableKey: "publishable-test-key",
        deployment: .staging
    )
    return OrganizerBackendHTTPClient(
        environment: environment,
        session: URLSession(configuration: configuration)
    ) {
        "access-token"
    }
}

private func adminEventFixture(id: UUID, limitKg: Int) -> BackendAdminEvent {
    BackendAdminEvent(
        id: id,
        name: "Acara Uji",
        description: "Deskripsi",
        startDate: Date(timeIntervalSince1970: 1_800_000_000),
        endDate: Date(timeIntervalSince1970: 1_800_086_400),
        capacityKg: 10,
        collectedKg: 0,
        bannerObjectPath: nil,
        status: .draft,
        timezoneName: "Asia/Jakarta",
        operationalDays: [6, 7],
        opensAtLocal: "08:00:00",
        closesAtLocal: "17:00:00",
        locationName: "Jakarta",
        locationAddress: "Jl. Test",
        latitude: -6.2,
        longitude: 106.8,
        criteria: [.cotton],
        maxDonationPerUserKg: limitKg
    )
}

private func eventRecordJSON() -> [String: Any] {
    [
        "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "name": "Acara Uji",
        "description": "Deskripsi",
        "status": "draft",
        "start_at": "2026-02-14T00:00:00Z",
        "end_at": "2026-02-21T00:00:00Z",
        "timezone_name": "Asia/Jakarta",
        "location_name": "Jakarta",
        "location_address": "Jl. Test",
        "latitude": -6.2,
        "longitude": 106.8,
        "capacity_grams": 10_000,
        "received_weight_grams": 0,
        "max_donation_per_user_grams": 1000,
        "banner_object_path": NSNull(),
        "receiver_name": "Workspace",
        "receiver_phone": "+6281234567890",
        "receiver_address": "Jl. Workspace",
        "criteria": ["cotton"],
    ]
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
