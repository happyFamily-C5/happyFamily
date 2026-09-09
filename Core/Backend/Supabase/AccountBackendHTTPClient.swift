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

struct AccountProfileData: Decodable, Sendable, Equatable {
    let id: UUID
    let role: AccountRoleCode?
    let displayName: String
    let phoneE164: String?
    let address: String?
    let recommendationLocationLabel: String?
    let avatarObjectPath: String?
}

struct AccountProfileUpdate: Encodable, Sendable, Equatable {
    let displayName: String
    let phoneE164: String
    let address: String
    let locationLabel: String
    let latitude: Double?
    let longitude: Double?
    let avatarObjectPath: String
}

struct AccountWorkspaceUpdate: Encodable, Sendable, Equatable {
    let name: String
    let address: String
    let phoneE164: String
    let email: String
    let logoObjectPath: String
}

struct AccountEmailChangeData: Decodable, Sendable, Equatable {
    let email: String?
    let emailChangeSentAt: Date?
    let pendingEmail: String?
}

protocol AccountBackendServing: Sendable {
    func completeOnboarding(role: AccountRoleCode) async throws -> AccountOnboardingData
    func myProfile() async throws -> AccountProfileData
    func updateProfile(_ update: AccountProfileUpdate) async throws -> AccountProfileData
    func updateWorkspace(_ update: AccountWorkspaceUpdate) async throws
    func requestEmailChange(email: String) async throws -> AccountEmailChangeData
    func dashboard() async throws -> DonorDashboardData
    func eventDetail(id: UUID) async throws -> DonorEventDetail
    func myBookings() async throws -> [DonorBookingListItem]
    func bookingDetail(id: UUID) async throws -> DonorBookingDetail
    func donationHistory(limit: Int, cursor: String?) async throws -> HistoryPage
    func eventHistory(terminal: Bool?, limit: Int, cursor: String?) async throws -> HistoryPage
    func createBooking(
        eventId: UUID,
        booking: AccountBookingBody,
        idempotencyKey: String
    ) async throws -> CreateBookingResult
    func cancelBooking(id: UUID, idempotencyKey: String) async throws -> CancelBookingResult
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

    func myProfile() async throws -> AccountProfileData {
        try await send(action: "my_profile", body: EmptyRequest())
    }

    func updateProfile(_ update: AccountProfileUpdate) async throws -> AccountProfileData {
        try await send(action: "update_profile", body: update)
    }

    func updateWorkspace(_ update: AccountWorkspaceUpdate) async throws {
        let _: EmptyResponse = try await send(action: "update_workspace", body: update)
    }

    func requestEmailChange(email: String) async throws -> AccountEmailChangeData {
        try await send(action: "request_email_change", body: EmailChangeRequest(email: email))
    }

    func dashboard() async throws -> DonorDashboardData {
        try await send(action: "dashboard", body: EmptyRequest())
    }

    func eventDetail(id: UUID) async throws -> DonorEventDetail {
        try await send(action: "event_detail", body: EventIDRequest(eventId: id))
    }

    func myBookings() async throws -> [DonorBookingListItem] {
        try await send(action: "my_bookings", body: EmptyRequest())
    }

    func bookingDetail(id: UUID) async throws -> DonorBookingDetail {
        try await send(action: "booking_detail", body: BookingIDRequest(bookingId: id))
    }

    func cancelBooking(id: UUID, idempotencyKey: String) async throws -> CancelBookingResult {
        try await send(
            action: "cancel_booking",
            body: BookingIDRequest(bookingId: id),
            idempotencyKey: idempotencyKey
        )
    }

    func donationHistory(limit: Int, cursor: String?) async throws -> HistoryPage {
        try await send(
            action: "donation_history",
            body: DonorHistoryRequest(limit: limit, cursor: cursor)
        )
    }

    func eventHistory(terminal: Bool?, limit: Int, cursor: String?) async throws -> HistoryPage {
        try await send(
            action: "event_history",
            body: DonorEventHistoryRequest(terminal: terminal, limit: limit, cursor: cursor)
        )
    }

    func createBooking(
        eventId: UUID,
        booking: AccountBookingBody,
        idempotencyKey: String
    ) async throws -> CreateBookingResult {
        try await send(
            action: "create_booking",
            body: AccountCreateBookingRequest(eventId: eventId, booking: booking),
            idempotencyKey: idempotencyKey
        )
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
private struct EmailChangeRequest: Encodable, Sendable { let email: String }
private struct EventIDRequest: Encodable, Sendable {
    let eventId: UUID
}

private struct DonorHistoryRequest: Encodable, Sendable {
    let limit: Int
    let cursor: String?
}

private struct DonorEventHistoryRequest: Encodable, Sendable {
    let terminal: Bool?
    let limit: Int
    let cursor: String?
}
