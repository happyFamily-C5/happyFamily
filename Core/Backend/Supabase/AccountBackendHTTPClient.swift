import Foundation

enum AccountRoleCode: String, Codable, Sendable {
    case admin
    case donor
}

struct AccountOnboardingData: Decodable, Sendable, Equatable {
    let role: AccountRoleCode
    let profileId: UUID
    let workspaceId: UUID?
}

struct AccountBookingDetail: Decodable, Sendable, Equatable {
    let id: UUID
    let publicBookingId: String
    let status: BookingStatusCode
    let estimatedWeightGrams: Int64
    let expiresAt: Date
    let canCancel: Bool
}

protocol AccountBackendServing: Sendable {
    func completeOnboarding(role: AccountRoleCode) async throws -> AccountOnboardingData
    func dashboard() async throws -> Data
    func bookingDetail(id: UUID) async throws -> AccountBookingDetail
    func cancelBooking(id: UUID, idempotencyKey: String) async throws
    func donationHistory() async throws -> Data
    func eventHistory() async throws -> Data
}

struct AccountBackendHTTPClient: AccountBackendServing, Sendable {
    private let environment: BackendEnvironment
    private let session: URLSession
    private let accessToken: @Sendable () async throws -> String

    init(
        environment: BackendEnvironment,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async throws -> String
    ) {
        self.environment = environment
        self.session = session
        self.accessToken = accessToken
    }

    func completeOnboarding(role: AccountRoleCode) async throws -> AccountOnboardingData {
        try await send(action: "complete_onboarding", body: OnboardingRequest(role: role))
    }

    func dashboard() async throws -> Data {
        try await sendRaw(action: "dashboard", body: EmptyRequest())
    }

    func bookingDetail(id: UUID) async throws -> AccountBookingDetail {
        try await send(action: "booking_detail", body: BookingIDRequest(bookingId: id))
    }

    func cancelBooking(id: UUID, idempotencyKey: String) async throws {
        let _: EmptyResponse = try await send(
            action: "cancel_booking",
            body: BookingIDRequest(bookingId: id),
            idempotencyKey: idempotencyKey
        )
    }

    func donationHistory() async throws -> Data {
        try await sendRaw(action: "donation_history", body: EmptyRequest())
    }

    func eventHistory() async throws -> Data {
        try await sendRaw(action: "event_history", body: EmptyRequest())
    }

    private func send<Value: Decodable & Sendable>(
        action: String,
        body: some Encodable & Sendable,
        idempotencyKey: String? = nil
    ) async throws -> Value {
        let data = try await sendRaw(action: action, body: body, idempotencyKey: idempotencyKey)
        let envelope = try BackendJSON.decoder().decode(BackendEnvelope<Value>.self, from: data)
        if let error = envelope.error {
            throw BackendError.api(code: error.code, retryable: error.retryable, fieldErrors: error.fieldErrors?.values ?? [:], requestId: envelope.requestId)
        }
        guard let value = envelope.data else { throw BackendError.invalidResponse }
        return value
    }

    private func sendRaw(
        action: String,
        body: some Encodable & Sendable,
        idempotencyKey: String? = nil
    ) async throws -> Data {
        var payload = try BackendJSON.encoder().encode(body)
        var object = (try JSONSerialization.jsonObject(with: payload) as? [String: Any]) ?? [:]
        object["action"] = action
        payload = try JSONSerialization.data(withJSONObject: object)
        var request = URLRequest(url: environment.functionsURL.appending(path: "account"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(environment.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Request-ID")
        if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard (200 ..< 300).contains(response.statusCode) else {
            if let envelope = try? BackendJSON.decoder().decode(BackendEnvelope<EmptyResponse>.self, from: data), let error = envelope.error {
                throw BackendError.api(code: error.code, retryable: error.retryable, fieldErrors: error.fieldErrors?.values ?? [:], requestId: envelope.requestId)
            }
            throw BackendError.invalidResponse
        }
        return data
    }
}

private struct EmptyRequest: Encodable, Sendable {}
private struct EmptyResponse: Decodable, Sendable {}
private struct OnboardingRequest: Encodable, Sendable { let role: AccountRoleCode }
private struct BookingIDRequest: Encodable, Sendable { let bookingId: UUID }
