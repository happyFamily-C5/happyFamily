import Foundation
@testable import happyFamily
import Testing

@Suite("Public backend HTTP client", .serialized)
struct PublicBackendClientTests {
    @Test func bookingRetryPreservesIdempotencyAndNeverEncodesPhotoData() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestHandler = { request in
            let attempt = recorder.record(request)
            let status = attempt == 1 ? 503 : 201
            let data = try attempt == 1 ? retryableErrorEnvelope() : bookingSuccessEnvelope()
            return try (response(for: request, status: status), data)
        }
        let client = makeClient()
        let request = bookingRequest()

        let result = try await client.createBooking(request, idempotencyKey: "booking-key-1234")

        #expect(result.bookingId == "KPL-ABCDE-FGHJK")
        let requests = recorder.snapshot()
        #expect(requests.count == 2)
        #expect(requests.allSatisfy {
            $0.idempotencyKey == "booking-key-1234"
        })
        let body = try #require(requests.first?.body)
        let json = try JSONSerialization.jsonObject(with: body)
        #expect(!containsForbiddenPhotoKey(json))
    }

    @Test func errorEnvelopeMapsStableCodeAndRequestID() async throws {
        let requestID = try #require(UUID(uuidString: "11111111-2222-4333-8444-555555555555"))
        URLProtocolStub.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "data": NSNull(),
                "error": [
                    "code": "PHONE_INVALID",
                    "retryable": false,
                    "field_errors": ["phone": "invalid"],
                ],
                "request_id": requestID.uuidString.lowercased(),
                "server_time": "2026-09-03T01:00:00Z",
            ])
            return try (response(for: request, status: 422), data)
        }

        await #expect {
            try await makeClient().createBooking(
                bookingRequest(),
                idempotencyKey: "booking-key-1234"
            )
        } throws: { error in
            guard case let BackendError.api(code, retryable, fields, receivedID) = error else {
                return false
            }
            return code == "PHONE_INVALID" && !retryable && fields == ["phone": "invalid"] &&
                receivedID == requestID
        }
    }

    @Test func cancelledTransportBecomesCancellationError() async {
        URLProtocolStub.requestHandler = { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            try await makeClient().resolveEvent(invocationToken: String(repeating: "a", count: 43))
        }
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

    func record(_ request: URLRequest) -> Int {
        lock.withLock {
            requests.append(RecordedRequest(
                idempotencyKey: request.value(forHTTPHeaderField: "Idempotency-Key"),
                body: requestBody(request)
            ))
            return requests.count
        }
    }

    func snapshot() -> [RecordedRequest] {
        lock.withLock { requests }
    }
}

private struct RecordedRequest: Sendable {
    let idempotencyKey: String?
    let body: Data?
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

private func makeClient() -> PublicBackendClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    let environment = BackendEnvironment(
        baseURL: URL(string: "https://api.example.invalid")!,
        publishableKey: "publishable-test-key",
        deployment: .staging
    )
    return PublicBackendClient(
        environment: environment,
        session: URLSession(configuration: configuration)
    )
}

private func bookingRequest() -> CreateBookingRequest {
    CreateBookingRequest(
        invocationToken: String(repeating: "i", count: 43),
        donorName: "Donor Test",
        phone: "081234567890",
        estimatedWeightGrams: 1000,
        itemCount: 1,
        items: [
            BookingItemRequest(
                ordinal: 0,
                passed: true,
                scannerModelVersion: "model-v1",
                metadata: ["garment_type": "shirt", "accessory_count": "0"]
            ),
        ],
        shippingMethod: .direct,
        scanModelVersion: "model-v1",
        termsVersion: "terms-v1",
        privacyVersion: "privacy-v1"
    )
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

private func retryableErrorEnvelope() throws -> Data {
    try JSONSerialization.data(withJSONObject: [
        "data": NSNull(),
        "error": ["code": "TEMPORARY_UNAVAILABLE", "retryable": true],
        "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "server_time": "2026-09-03T01:00:00Z",
    ])
}

private func bookingSuccessEnvelope() throws -> Data {
    try JSONSerialization.data(withJSONObject: [
        "data": [
            "booking_id": "KPL-ABCDE-FGHJK",
            "status": "waiting",
            "expires_at": "2026-09-03T13:00:00Z",
            "qr_token": String(repeating: "q", count: 43),
            "qr_payload": "https://example.invalid/booking/qr",
            "label_snapshot": publicEventJSON(),
            "idempotent_replay": false,
        ],
        "error": NSNull(),
        "request_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "server_time": "2026-09-03T01:00:00Z",
    ])
}

private func publicEventJSON() -> [String: Any] {
    [
        "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        "name": "Event Test",
        "description": "Description",
        "status": "ongoing",
        "availability": "available",
        "start_at": "2026-09-03T00:00:00Z",
        "end_at": "2026-09-03T14:00:00Z",
        "timezone_name": "Asia/Jakarta",
        "operational_days": [1, 2, 3],
        "opens_at_local": "08:00:00",
        "closes_at_local": "17:00:00",
        "location_name": "Jakarta",
        "location_address": "Jl. Test",
        "latitude": -6.2,
        "longitude": 106.8,
        "capacity_grams": 100_000,
        "received_weight_grams": 1000,
        "banner_object_path": "workspace/event/banner.jpg",
        "receiver_name": "Receiver",
        "receiver_phone": "+6281234567890",
        "receiver_address": "Jl. Receiver",
        "criteria": ["cotton"],
        "version": 2,
        "schema_version": 1,
        "captured_at": "2026-09-03T01:00:00Z",
    ]
}

private func containsForbiddenPhotoKey(_ value: Any) -> Bool {
    if let dictionary = value as? [String: Any] {
        for (key, nested) in dictionary {
            if key.range(
                of: "photo|image|binary|blob|exif|embedding|path|history|attempt",
                options: .regularExpression
            ) != nil || containsForbiddenPhotoKey(nested) {
                return true
            }
        }
    } else if let array = value as? [Any] {
        return array.contains(where: containsForbiddenPhotoKey)
    }
    return false
}
