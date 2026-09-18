import Foundation
@testable import happyFamily
import Testing

@Suite("Account donor client", .serialized)
struct AccountDonorClientTests {
    @Test("deleteAccount sends the authenticated account deletion action")
    func deleteAccountPostsDeletionAction() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [:],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        try await makeAccountClient().deleteAccount()

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/account")
        #expect(request.authorization == "Bearer access-token")
        #expect(request.jsonBody?["action"] as? String == "delete_account")
    }

    @Test("profile and workspace updates normalize Indonesian phone numbers")
    func profileAndWorkspaceUpdatesNormalizePhones() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [:],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        try await makeAccountClient().updateWorkspace(AccountWorkspaceUpdate(
            name: "Kantor Uji",
            address: "Jakarta",
            phoneE164: "0812-3456-7890",
            email: "kantor@example.invalid",
            logoObjectPath: ""
        ))

        let json = try #require(recorder.snapshot().first?.jsonBody)
        #expect(json["action"] as? String == "update_workspace")
        #expect(json["phone_e164"] as? String == "+6281234567890")

        _ = try? await makeAccountClient().updateProfile(AccountProfileUpdate(
            displayName: "Donatur Uji", phoneE164: "0812-3456-7890", address: "Jakarta",
            locationLabel: "", latitude: nil, longitude: nil, avatarObjectPath: ""
        ))
        let profileJSON = try #require(recorder.snapshot().last?.jsonBody)
        #expect(profileJSON["action"] as? String == "update_profile")
        #expect(profileJSON["phone_e164"] as? String == "+6281234567890")
    }

    @Test("createBooking posts the account action with the idempotency key")
    func createBookingPostsAccountBody() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": createBookingResultJSON(),
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 201), data)
        }
        let eventId = UUID()

        let result = try await makeAccountClient().createBooking(
            eventId: eventId,
            booking: bookingBody(),
            idempotencyKey: "booking-key-1234"
        )

        let request = try #require(recorder.snapshot().first)
        #expect(request.url?.path == "/functions/v1/account")
        #expect(request.method == "POST")
        #expect(request.idempotencyKey == "booking-key-1234")
        let json = try #require(request.jsonBody)
        #expect(json["action"] as? String == "create_booking")
        #expect(UUID(uuidString: json["event_id"] as? String ?? "") == eventId)
        let booking = try #require(json["booking"] as? [String: Any])
        #expect(booking["estimated_weight_grams"] as? Int64 == 1000)
        #expect(booking["item_count"] as? Int == 2)
        #expect(booking["shipping_method"] as? String == "direct")
        #expect((booking["items"] as? [[String: Any]])?.count == 2)
        #expect(booking["terms_version"] == nil)
        #expect(booking["privacy_version"] == nil)
        #expect(booking["donor_name"] == nil)

        #expect(result.bookingId == UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"))
        #expect(result.publicBookingId == "KMP-TEST-001")
        #expect(result.status == .waiting)
        #expect(result.qrToken == "opaque-qr-token")
        #expect(result.eventSnapshot.name == "Acara Uji")
        #expect(result.idempotentReplay == false)
    }

    @Test("dashboard decodes the three donor rails")
    func dashboardDecodesRails() async throws {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "profile_complete": true,
                    "active_events": [donorEventJSON()],
                    "recommended_events": [],
                    "trending_events": [donorEventJSON()],
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let dashboard = try await makeAccountClient().dashboard()

        #expect(dashboard.profileComplete)
        #expect(dashboard.activeEvents.count == 1)
        #expect(dashboard.activeEvents.first?.organizationName == "EcoTouch Indonesia")
        #expect(dashboard.trendingEvents.count == 1)
        #expect(dashboard.recommendedEvents.isEmpty)
    }

    @Test("eventDetail decodes event and availability")
    func eventDetailDecodesAvailability() async throws {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                    "name": "Acara Uji",
                    "description": NSNull(),
                    "status": "ongoing",
                    "start_at": "2026-02-14T00:00:00Z",
                    "end_at": "2026-02-21T00:00:00Z",
                    "timezone_name": "Asia/Jakarta",
                    "location_name": "Jakarta",
                    "capacity_grams": 10000,
                    "received_weight_grams": 1000,
                    "reserved_weight_grams": 500,
                    "used_weight_grams": 1500,
                    "max_donation_per_user_grams": 5000,
                    "organization_name": "EcoTouch Indonesia",
                    "distance_km": 1.4,
                    "criteria": ["cotton"],
                    "availability": [
                        "bookable": true,
                        "available_weight_grams": 8500,
                    ],
                    "already_booked": false,
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let detail = try await makeAccountClient().eventDetail(id: UUID())

        #expect(detail.event.name == "Acara Uji")
        #expect(detail.event.description == nil)
        #expect(detail.event.usedWeightGrams == 1500)
        #expect(detail.event.distanceKm == 1.4)
        #expect(detail.availability.bookable)
        #expect(detail.availability.availableWeightGrams == 8500)
        #expect(!detail.alreadyBooked)
    }

    @Test("myBookings decodes the bare array with availability-free snapshots")
    func myBookingsDecodesArray() async throws {
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [myBookingJSON()],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let bookings = try await makeAccountClient().myBookings()

        #expect(bookings.count == 1)
        let booking = try #require(bookings.first)
        #expect(booking.status == .waiting)
        #expect(booking.canCancel)
        #expect(booking.event.capacityGrams == 10000)
        #expect(booking.actualWeightGrams == nil)
    }

    @Test("bookingDetail decodes the timeline and the owner QR token")
    func bookingDetailDecodesTimelineAndQR() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": bookingDetailJSON(qrToken: "opaque-qr-token"),
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }
        let bookingId = UUID()

        let detail = try await makeAccountClient().bookingDetail(id: bookingId)

        let request = try #require(recorder.snapshot().first)
        #expect(try UUID(uuidString: #require(request.jsonBody?["booking_id"] as? String)) == bookingId)
        #expect(detail.status == .accepted)
        #expect(detail.canCancel == false)
        #expect(detail.qrToken == "opaque-qr-token")
        #expect(detail.timeline.count == 2)
        #expect(detail.timeline.first?.status == .waiting)
        #expect(detail.timeline.last?.actorType == "admin")
    }

    @Test("donationHistory sends limit and cursor and decodes the page")
    func donationHistorySendsPagination() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "items": [historyItemJSON()],
                    "next_cursor": "opaque-next-cursor",
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let page = try await makeAccountClient().donationHistory(limit: 20, cursor: "opaque-current-cursor")

        let json = try #require(recorder.snapshot().first?.jsonBody)
        #expect(json["action"] as? String == "donation_history")
        #expect(json["limit"] as? Int == 20)
        #expect(json["cursor"] as? String == "opaque-current-cursor")
        #expect(page.items.count == 1)
        #expect(page.nextCursor == "opaque-next-cursor")
        #expect(page.items.first?.status == .accepted)
    }

    @Test("eventHistory forwards the terminal filter")
    func eventHistoryForwardsTerminal() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "items": [historyItemJSON()],
                    "next_cursor": NSNull(),
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }

        let page = try await makeAccountClient().eventHistory(terminal: true, limit: 20, cursor: nil)

        let json = try #require(recorder.snapshot().first?.jsonBody)
        #expect(json["action"] as? String == "event_history")
        #expect(json["terminal"] as? Bool == true)
        #expect(page.items.count == 1)
        #expect(page.nextCursor == nil)
    }

    @Test("cancelBooking decodes the cancelled result")
    func cancelBookingDecodesResult() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            recorder.record(request)
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                    "status": "cancelled",
                    "hidden_from_operational_lists": true,
                ],
                "error": NSNull(),
                "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                "server_time": "2026-09-10T01:00:00Z",
            ])
            return try (response(for: request, status: 200), data)
        }
        let bookingId = UUID()

        let result = try await makeAccountClient().cancelBooking(
            id: bookingId,
            idempotencyKey: "cancel-booking-\(bookingId.uuidString)"
        )

        let request = try #require(recorder.snapshot().first)
        #expect(request.idempotencyKey == "cancel-booking-\(bookingId.uuidString)")
        #expect(result.status == .cancelled)
    }
}

// MARK: - Fixtures

private func bookingBody() -> AccountBookingBody {
    AccountBookingBody(
        estimatedWeightGrams: 1000,
        itemCount: 2,
        items: [
            AccountBookingItem(ordinal: 0, passed: true, scannerModelVersion: "accessory-head-v1", metadata: ["garment_type": "shirt"]),
            AccountBookingItem(ordinal: 1, passed: true, scannerModelVersion: "accessory-head-v1", metadata: [:]),
        ],
        shippingMethod: .direct,
        scanModelVersion: "accessory-head-v1"
    )
}

private func donorEventJSON() -> [String: Any] {
    [
        "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "name": "Acara Uji",
        "description": "Deskripsi",
        "status": "ongoing",
        "start_at": "2026-02-14T00:00:00Z",
        "end_at": "2026-02-21T00:00:00Z",
        "timezone_name": "Asia/Jakarta",
        "location_name": "Jakarta",
        "capacity_grams": 10000,
        "received_weight_grams": 1000,
        "reserved_weight_grams": 500,
        "used_weight_grams": 1500,
        "max_donation_per_user_grams": 5000,
        "banner_object_path": NSNull(),
        "organization_name": "EcoTouch Indonesia",
        "distance_km": 1.4,
        "criteria": ["cotton"],
    ]
}

private func myBookingJSON() -> [String: Any] {
    [
        "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "public_booking_id": "KMP-TEST-001",
        "status": "waiting",
        "estimated_weight_grams": 500,
        "actual_weight_grams": NSNull(),
        "expires_at": "2026-02-21T00:00:00Z",
        "event": donorEventJSON(),
        "can_cancel": true,
        "created_at": "2026-09-10T01:00:00Z",
        "status_updated_at": "2026-09-10T01:00:00Z",
    ]
}

private func bookingDetailJSON(qrToken: String?) -> [String: Any] {
    var json: [String: Any] = [
        "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "public_booking_id": "KMP-TEST-001",
        "status": "accepted",
        "estimated_weight_grams": 500,
        "actual_weight_grams": 750,
        "expires_at": "2026-02-21T00:00:00Z",
        "event": donorEventJSON(),
        "can_cancel": false,
        "timeline": [
            [
                "previous_status": NSNull(),
                "status": "waiting",
                "actor_type": "donor",
                "created_at": "2026-09-10T01:00:00Z",
            ],
            [
                "previous_status": "waiting",
                "status": "accepted",
                "actor_type": "admin",
                "created_at": "2026-09-10T02:00:00Z",
            ],
        ],
    ]
    if let qrToken {
        json["qr_token"] = qrToken
        json["qr_token_ciphertext"] = "ciphertext"
        json["qr_token_nonce"] = "nonce"
    }
    return json
}

private func historyItemJSON() -> [String: Any] {
    [
        "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "public_booking_id": "KMP-TEST-001",
        "status": "accepted",
        "estimated_weight_grams": 500,
        "actual_weight_grams": 750,
        "created_at": "2026-09-10T01:00:00Z",
        "status_updated_at": "2026-09-10T02:00:00Z",
        "event": donorEventJSON(),
    ]
}

private func createBookingResultJSON() -> [String: Any] {
    [
        "booking_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "public_booking_id": "KMP-TEST-001",
        "status": "waiting",
        "expires_at": "2026-02-21T00:00:00Z",
        "event_snapshot": donorEventJSON(),
        "qr_token": "opaque-qr-token",
        "idempotent_replay": false,
    ]
}

// MARK: - Harness (file-local copies)

private func makeAccountClient() -> AccountBackendHTTPClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    let environment = BackendEnvironment(
        baseURL: URL(string: "https://api.example.invalid")!,
        publishableKey: "publishable-test-key",
        deployment: .staging
    )
    return AccountBackendHTTPClient(
        environment: environment,
        session: URLSession(configuration: configuration)
    ) {
        "access-token"
    }
}

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
