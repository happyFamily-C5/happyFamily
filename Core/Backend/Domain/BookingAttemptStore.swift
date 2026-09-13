import Foundation

/// A booking submission held between "user tapped submit" and "server
/// confirmed". The idempotency key and exact payload persist so a retry after
/// process death replays the same request instead of risking
/// `IDEMPOTENCY_CONFLICT` (same key, other payload) or a duplicate booking
/// (new key after a timed-out success).
struct PendingBookingAttempt: Codable, Equatable, Sendable {
    let eventId: UUID
    let idempotencyKey: String
    /// Canonical wire encoding of the booking body; byte equality decides
    /// whether a stored key may be reused.
    let payload: Data
    let createdAt: Date
}

/// UserDefaults-backed single-slot store. The attempt is one small value
/// whose loss would only cost a duplicate key generation, so a persistent
/// UserDefaults beats a SwiftData container here.
struct BookingAttemptStore: @unchecked Sendable {
    let defaults: UserDefaults

    static let storageKey = "pendingBookingAttempt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func pending() -> PendingBookingAttempt? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? BackendJSON.decoder().decode(PendingBookingAttempt.self, from: data)
    }

    func store(_ attempt: PendingBookingAttempt) {
        guard let data = try? BackendJSON.encoder().encode(attempt) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Builds or reuses the attempt for `eventId` with `payload`. Returns the
    /// idempotency key to send.
    func resolveAttempt(eventId: UUID, payload: Data) -> PendingBookingAttempt {
        if let existing = pending(), existing.eventId == eventId, existing.payload == payload {
            return existing
        }
        let attempt = PendingBookingAttempt(
            eventId: eventId,
            idempotencyKey: UUID().uuidString.lowercased(),
            payload: payload,
            createdAt: Date()
        )
        store(attempt)
        return attempt
    }
}

/// Encodes the booking body canonically for attempt comparison. Uses the
/// shared encoder so wire bytes and stored bytes match exactly.
func bookingBodyPayload(_ body: AccountBookingBody) throws -> Data {
    try BackendJSON.encoder().encode(body)
}
