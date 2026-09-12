import Foundation
@testable import happyFamily
import Testing

@Suite("Organizer operations edge client", .serialized)
struct OrganizerOperationsClientTests {
    @Test("resolveQR posts the opaque token to operations")
    func resolveQRPostsOperationsBody() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": resolvedQRJSON(),
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }
        let token = String(repeating: "q", count: 64)

        let booking = try await makeClient().resolveQR(token: token)

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/operations")
        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "resolve_qr")
        #expect(json["qr_token"] as? String == token)
        #expect(booking.bookingId == UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"))
    }

    @Test("publish posts operations action with a stable idempotency key")
    func publishPostsOperationsBody() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "invocation_url": "https://app.example.invalid/event/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }
        let eventId = UUID()

        let published = try await makeClient().publish(eventId: eventId)

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/operations")
        #expect(request.idempotencyKey == "publish-event-\(eventId.uuidString)")
        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "publish_event")
        #expect(UUID(uuidString: json["event_id"] as? String ?? "") == eventId)
        #expect(
            published.invocationURL?.absoluteString ==
                "https://app.example.invalid/event/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
        )
    }

    @Test("publish validation exposes each missing event field")
    func publishValidationExposesFieldErrors() async {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": NSNull(),
                "error": [
                    "code": "EVENT_PUBLISH_FIELDS_REQUIRED",
                    "retryable": false,
                    "field_errors": [
                        "banner": "Banner acara belum diunggah.",
                        "description": "Deskripsi acara belum diisi.",
                    ],
                ],
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 422), data)
        }

        await #expect {
            _ = try await makeClient().publish(eventId: UUID())
        } throws: { error in
            guard case let BackendError.api(code, retryable, fieldErrors, _) = error else {
                return false
            }
            return code == "EVENT_PUBLISH_FIELDS_REQUIRED"
                && !retryable
                && fieldErrors == [
                    "banner": "Banner acara belum diunggah.",
                    "description": "Deskripsi acara belum diisi.",
                ]
                && error.localizedDescription.contains("Banner acara belum diunggah.")
        }
    }

    @Test("publish accepts the deployed event-only success response")
    func publishAcceptsEventOnlySuccessResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": eventRecordJSON(),
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let published = try await makeClient().publish(eventId: UUID())

        #expect(published.invocationURL == nil)
    }

    @Test("listEvents posts the operations list action and decodes next cursor")
    func listEventsPostsOperationsBody() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "items": [eventRecordJSON()],
                    "next_cursor": "opaque-next-cursor",
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let page = try await makeClient().listEvents(cursor: "opaque-current-cursor")

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/operations")
        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "list_events")
        #expect(json["cursor"] as? String == "opaque-current-cursor")
        #expect(json["limit"] as? Int == 100)
        #expect(page.items.count == 1)
        #expect(page.nextCursor == "opaque-next-cursor")
    }

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

    @Test("reception and tracking mutations use operations with idempotency")
    func receptionAndTrackingUseOperations() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": receptionDecisionJSON(), "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }
        let bookingId = UUID()
        let input = ReceptionDecisionInput(
            bookingId: bookingId, decision: .accepted, actualWeightGrams: 750,
            condition: .good, rejectionReason: nil, rejectionNote: nil,
            idempotencyKey: "reception-\(bookingId.uuidString)", requestId: UUID()
        )

        _ = try await makeClient().decideReception(input)
        _ = try await makeClient().advanceTracking(bookingId: bookingId, status: .processed)

        let requests = recorder.snapshot()
        let reception = try #require(requests.first)
        #expect(reception.url?.path == "/functions/v1/operations")
        #expect(reception.idempotencyKey == input.idempotencyKey)
        #expect(reception.jsonBody?["action"] as? String == "decide_reception")
        #expect(reception.jsonBody?["condition"] == nil)
        let tracking = try #require(requests.last)
        #expect(tracking.idempotencyKey == "advance-tracking-\(bookingId.uuidString)-processed")
        #expect(tracking.jsonBody?["action"] as? String == "advance_tracking")
    }

    @Test("recap posts the operations action and decodes the safe recent rows")
    func recapUsesOperations() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "month": ["accepted_weight_grams": 750, "accepted_count": 1, "unique_donor_count": 1],
                    "recent_donations": [[
                        "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                        "public_booking_id": "KMP-TEST-001", "donor_name": "Donor Uji",
                        "actual_weight_grams": 750, "event_name": "Acara Uji",
                        "received_at": "2026-09-10T01:00:00Z",
                    ]],
                ],
                "error": NSNull(), "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let recap = try await makeClient().recap(eventId: nil)

        let request = try #require(recorder.snapshot().first)
        #expect(request.jsonBody?["action"] as? String == "recap")
        #expect(recap.month.acceptedWeightGrams == 750)
        #expect(recap.recentDonations.first?.donorName == "Donor Uji")
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

    @Test("donationHistory posts the operations action and decodes the page")
    func donationHistoryPostsOperationsBody() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "items": [bookingHistoryItemJSON()],
                    "next_cursor": "opaque-next-cursor",
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let page = try await makeClient().donationHistory(eventId: nil, cursor: "opaque-current-cursor")

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/operations")
        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "donation_history")
        #expect(json["cursor"] as? String == "opaque-current-cursor")
        #expect(json["limit"] as? Int == 20)
        let item = try #require(page.items.first)
        #expect(item.bookingId == UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"))
        #expect(item.publicBookingId == "KMP-TEST-001")
        #expect(item.status == .accepted)
        #expect(item.estimatedWeightGrams == 500)
        #expect(item.actualWeightGrams == 750)
        #expect(item.event.name == "Acara Uji")
        #expect(page.nextCursor == "opaque-next-cursor")
    }

    @Test("eventHistory posts the operations action and decodes the page")
    func eventHistoryPostsOperationsBody() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            var item = bookingHistoryItemJSON()
            item["status"] = "processed"
            item["actual_weight_grams"] = 900
            if var event = item["event"] as? [String: Any] {
                event["status"] = "upcoming"
                event["banner_object_path"] = "workspace/banner.png"
                item["event"] = event
            }
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "items": [item],
                    "next_cursor": NSNull(),
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let page = try await makeClient().eventHistory(eventId: nil, cursor: nil)

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/operations")
        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "event_history")
        #expect(json["cursor"] == nil)
        #expect(json["limit"] as? Int == 20)
        let item = try #require(page.items.first)
        #expect(item.status == .processed)
        #expect(item.event.status == .upcoming)
        #expect(item.event.bannerObjectPath == "workspace/banner.png")
        #expect(page.nextCursor == nil)
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

private func bookingHistoryItemJSON() -> [String: Any] {
    [
        "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "public_booking_id": "KMP-TEST-001",
        "status": "accepted",
        "estimated_weight_grams": 500,
        "actual_weight_grams": 750,
        "created_at": "2026-09-10T01:00:00Z",
        "status_updated_at": "2026-09-10T02:00:00Z",
        "event": [
            "id": "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff",
            "name": "Acara Uji",
            "status": "ongoing",
            "start_at": "2026-02-14T00:00:00Z",
            "end_at": "2026-02-21T00:00:00Z",
            "location_name": "Jakarta",
            "banner_object_path": NSNull(),
        ],
    ]
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

private func resolvedQRJSON() -> [String: Any] {
    [
        "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "public_booking_id": "KMP-TEST-001",
        "status": "waiting",
        "estimated_weight_grams": 500,
        "item_count": 1,
        "shipping_method": "direct",
        "donor_name": "Donor Uji",
        "donor_phone": "+6281234567890",
        "event_snapshot": [
            "id": "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff",
            "name": "Acara Uji",
            "description": "Deskripsi",
            "status": "ongoing",
            "availability": "available",
            "start_at": "2026-02-14T00:00:00Z",
            "end_at": "2026-02-21T00:00:00Z",
            "timezone_name": "Asia/Jakarta",
            "operational_days": [6, 7],
            "opens_at_local": "08:00:00",
            "closes_at_local": "17:00:00",
            "location_name": "Jakarta",
            "location_address": "Jl. Test",
            "latitude": -6.2,
            "longitude": 106.8,
            "capacity_grams": 10_000,
            "received_weight_grams": 0,
            "banner_object_path": "workspace/banner.png",
            "receiver_name": "Workspace",
            "receiver_phone": "+6281234567890",
            "receiver_address": "Jl. Workspace",
            "criteria": ["cotton"],
            "version": 1,
        ],
    ]
}

private func receptionDecisionJSON() -> [String: Any] {
    [
        "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "public_booking_id": "KMP-TEST-001",
        "status": "accepted",
        "received_weight_grams": 750,
        "capacity_grams": 10_000,
        "capacity_full": false,
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
