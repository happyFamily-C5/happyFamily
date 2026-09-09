import Foundation

/// Donor-facing event row (`event_user_json`): workspace branding, capacity
/// breakdown, and the optional distance from the donor's recommendation
/// location. This snapshot shape is also embedded in every booking response.
struct DonorEventDTO: Decodable, Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let status: EventStatusCode
    let startAt: Date?
    let endAt: Date?
    let timezoneName: String?
    let locationName: String?
    let locationAddress: String?
    let latitude: Double?
    let longitude: Double?
    let capacityGrams: Int64?
    let receivedWeightGrams: Int64
    let reservedWeightGrams: Int64
    let usedWeightGrams: Int64
    let maxDonationPerUserGrams: Int64?
    let bannerObjectPath: String?
    let receiverName: String?
    let receiverPhone: String?
    let receiverAddress: String?
    let organizationName: String?
    let organizationLogoObjectPath: String?
    let distanceKm: Double?
    let criteria: [EventCriterionCode]

    var capacityKg: Int? {
        capacityGrams.map { Int($0 / 1000) }
    }
}

struct DonorEventAvailability: Decodable, Equatable, Sendable {
    let bookable: Bool
    let availableWeightGrams: Int64?
}

/// Legal versions are server-owned; the UI must use these when creating a
/// booking instead of hardcoding version identifiers.
struct DonorLegalData: Decodable, Equatable, Sendable {
    let termsVersion: String
    let termsURL: URL
    let privacyVersion: String
    let privacyURL: URL

    /// The shared decoder converts snake keys to lowerCamelCase, so the
    /// acronym URLs must be matched against "termsUrl"/"privacyUrl".
    enum CodingKeys: String, CodingKey {
        case termsVersion
        case termsURL = "termsUrl"
        case privacyVersion
        case privacyURL = "privacyUrl"
    }
}

/// `account:event_detail`: the donor event JSON flattened with availability,
/// the already-booked flag, and the environment's active legal documents.
struct DonorEventDetail: Decodable, Equatable, Sendable {
    let event: DonorEventDTO
    let availability: DonorEventAvailability
    let alreadyBooked: Bool
    let legal: DonorLegalData
    /// Keys are camelCase because the shared decoder applies
    /// convertFromSnakeCase before custom containers see them.
    private enum ExtraKeys: String, CodingKey {
        case availability
        case alreadyBooked
        case legal
    }

    init(from decoder: Decoder) throws {
        event = try DonorEventDTO(from: decoder)
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        availability = try container.decode(DonorEventAvailability.self, forKey: .availability)
        alreadyBooked = try container.decode(Bool.self, forKey: .alreadyBooked)
        legal = try container.decode(DonorLegalData.self, forKey: .legal)
    }
}

/// `account:dashboard` for donors: completion flag plus three event rails.
struct DonorDashboardData: Decodable, Equatable, Sendable {
    let profileComplete: Bool
    let activeEvents: [DonorEventDTO]
    let recommendedEvents: [DonorEventDTO]
    let trendingEvents: [DonorEventDTO]
}

/// Row of `account:my_bookings` (non-cancelled bookings of the donor).
struct DonorBookingListItem: Decodable, Equatable, Sendable, Identifiable {
    let bookingId: UUID
    let publicBookingId: String
    let status: BookingStatusCode
    let estimatedWeightGrams: Int64
    let actualWeightGrams: Int64?
    let expiresAt: Date
    let event: DonorEventDTO
    let canCancel: Bool
    let createdAt: Date
    let statusUpdatedAt: Date?

    var id: UUID { bookingId }
}

struct DonorBookingTimelineEntry: Decodable, Equatable, Sendable, Identifiable {
    let previousStatus: BookingStatusCode?
    let status: BookingStatusCode
    let actorType: String
    let createdAt: Date

    var id: String {
        "\(createdAt.timeIntervalSince1970)-\(status.rawValue)-\(previousStatus?.rawValue ?? "root")-\(actorType)"
    }
}

/// `account:booking_detail`. `qr_token` is present only for the owning donor
/// while PII is intact; it must be kept in secure local storage only.
struct DonorBookingDetail: Decodable, Equatable, Sendable {
    let id: UUID
    let publicBookingId: String
    let status: BookingStatusCode
    let estimatedWeightGrams: Int64
    let actualWeightGrams: Int64?
    let expiresAt: Date
    let event: DonorEventDTO
    let canCancel: Bool
    let timeline: [DonorBookingTimelineEntry]
    let qrToken: String?
}

/// Booking body accepted by `account:create_booking` — exactly the seven
/// allowed keys; anything else is rejected server-side.
struct AccountBookingBody: Encodable, Sendable, Equatable {
    let estimatedWeightGrams: Int64
    let itemCount: Int
    let items: [AccountBookingItem]
    let shippingMethod: ShippingMethodCode
    let scanModelVersion: String
    let termsVersion: String
    let privacyVersion: String
}

struct AccountBookingItem: Encodable, Sendable, Equatable {
    let ordinal: Int
    let passed: Bool
    let scannerModelVersion: String
    let metadata: [String: String]
}

struct AccountCreateBookingRequest: Encodable, Sendable, Equatable {
    let eventId: UUID
    let booking: AccountBookingBody
}

/// Response of `account:create_booking`. `qr_token` is the durable opaque
/// token (stable across idempotent replays); store it in the Keychain only.
struct CreateBookingResult: Decodable, Equatable, Sendable {
    let bookingId: UUID
    let publicBookingId: String
    let status: BookingStatusCode
    let expiresAt: Date
    let eventSnapshot: DonorEventDTO
    let qrToken: String
    let idempotentReplay: Bool
}

/// Response of `account:cancel_booking`.
struct CancelBookingResult: Decodable, Equatable, Sendable {
    let bookingId: UUID
    let status: BookingStatusCode
}
