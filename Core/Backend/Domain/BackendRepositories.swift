import Foundation

struct EventPage: Sendable, Equatable {
    let events: [BackendAdminEvent]
    let cursor: String?
}

struct BannerUploadData: Decodable, Sendable, Equatable {
    let objectPath: String
    let contentType: String
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case objectPath
        case contentType
        case width
        case height
    }
}

protocol EventRepository: Sendable {
    func list(cursor: String?) async throws -> EventPage
    func upsertDraft(_ event: BackendAdminEvent, mutationId: UUID) async throws -> BackendAdminEvent
    func publish(eventId: UUID) async throws -> PublishEventData
    func cancelOrDelete(eventId: UUID) async throws -> CancelEventData
}

struct PendingDraftSync: Sendable, Equatable {
    let event: BackendAdminEvent
    let mutationId: UUID
}

protocol EventLocalStore: SessionCache, Sendable {
    func cachedEvents(ownerUserId: UUID) async throws -> [BackendAdminEvent]
    func cursor(ownerUserId: UUID) async throws -> String?
    func cacheRemoteEvents(
        _ events: [BackendAdminEvent],
        cursor: String?,
        ownerUserId: UUID
    ) async throws
    func enqueueDraft(
        _ event: BackendAdminEvent,
        mutationId: UUID,
        ownerUserId: UUID
    ) async throws
    func pendingDrafts(ownerUserId: UUID) async throws -> [PendingDraftSync]
    func markDraftSynced(
        _ event: BackendAdminEvent,
        mutationId: UUID,
        ownerUserId: UUID
    ) async throws
    func discardDraft(
        eventId: UUID,
        mutationId: UUID,
        ownerUserId: UUID
    ) async throws
    /// Removes a deleted event's cached row and any queued draft for it.
    func deleteEvent(eventId: UUID, ownerUserId: UUID) async throws
}

struct AuthUserSession: Sendable, Equatable {
    let userId: UUID
    let accessToken: String
    let expiresAt: Date
}

protocol AuthSession: Sendable {
    func current() async throws -> AuthUserSession
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws -> AuthUserSession
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUserSession
    func signOut() async throws
}

protocol SessionCache: Sendable {
    func purge() async
}

struct LogoutService: Sendable {
    let auth: any AuthSession
    let cache: any SessionCache
    /// Best-effort purge of secure storage rows (donor QR tokens). Runs only
    /// after a successful global sign-out so a failed logout keeps tokens.
    var qrPurge: (@Sendable () async -> Void)?

    func logout() async throws {
        try await auth.signOut()
        await cache.purge()
        await qrPurge?()
    }
}

enum ReceptionDecisionCode: String, Encodable, Sendable {
    case accepted
    case rejected
}

enum ReceptionConditionCode: String, Encodable, Sendable {
    case good
    case damaged
    case wet
    case dirty
    case moldy
}

enum RejectionReasonCode: String, Encodable, Sendable {
    case accessoriesAttached = "accessories_attached"
    case criteriaMismatch = "criteria_mismatch"
    case damaged
    case wet
    case dirty
    case moldy
    case capacityExceeded = "capacity_exceeded"
    case other
}

struct ReceptionDecisionInput: Encodable, Sendable {
    let bookingId: UUID
    let decision: ReceptionDecisionCode
    let actualWeightGrams: Int64
    let condition: ReceptionConditionCode
    let rejectionReason: RejectionReasonCode?
    let rejectionNote: String?
    let idempotencyKey: String
    let requestId: UUID
}

protocol ReceptionRepository: Sendable {
    func resolveQR(token: String) async throws -> ResolvedQRBooking
    func decide(_ input: ReceptionDecisionInput) async throws -> ReceptionDecisionData
    func advanceTracking(bookingId: UUID, status: BookingStatusCode) async throws -> ReceptionDecisionData
}

protocol ReportRepository: Sendable {
    func recap(eventId: UUID?) async throws -> AdminRecapData
    func donationHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage
    func eventHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage
}
