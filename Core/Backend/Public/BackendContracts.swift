import Foundation

enum EventStatusCode: String, Codable, CaseIterable, Sendable {
    case draft
    case upcoming
    case ongoing
    case completed
    case closed
    case cancelled
}

enum BookingStatusCode: String, Codable, CaseIterable, Sendable {
    case waiting
    case accepted
    case rejected
    case expired
    case cancelled
}

enum EventAvailabilityCode: String, Codable, Sendable {
    case available
    case availableUpcoming = "available_upcoming"
    case full
    case completed
    case closed
    case cancelled
    case unavailable

    var acceptsBookings: Bool {
        self == .available || self == .availableUpcoming
    }
}

enum ShippingMethodCode: String, Codable, CaseIterable, Sendable {
    case direct
    case ojekOnline = "ojek_online"
    case expedition
}

enum EventCriterionCode: String, Codable, CaseIterable, Sendable {
    case cotton
    case linen
    case rayon
    case wool
    case tencel
    case silk
    case nonStretch = "non_stretch"
    case denim
    case noLace = "no_lace"
    case polyester
}

struct BackendFieldErrors: Codable, Equatable, Sendable {
    let values: [String: String]

    init(from decoder: Decoder) throws {
        values = try [String: String](from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try values.encode(to: encoder)
    }
}

struct BackendErrorPayload: Decodable, Equatable, Sendable {
    let code: String
    let retryable: Bool
    let fieldErrors: BackendFieldErrors?
}

struct BackendEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value?
    let error: BackendErrorPayload?
    let requestId: UUID
    let serverTime: Date
}

enum BackendError: Error, Equatable, Sendable, LocalizedError {
    case configuration(String)
    case invalidInvocationURL
    case invalidResponse
    case transport(String)
    case decoding(String)
    case api(code: String, retryable: Bool, fieldErrors: [String: String], requestId: UUID?)

    var errorDescription: String? {
        switch self {
        case let .configuration(key):
            "Konfigurasi backend \(key) belum tersedia."
        case .invalidInvocationURL:
            "Tautan acara tidak valid."
        case .invalidResponse:
            "Respons server tidak valid."
        case .transport:
            "Koneksi ke server gagal. Coba lagi."
        case .decoding:
            "Data dari server tidak dapat dibaca."
        case let .api(code, _, _, _):
            Self.localizedMessage(for: code)
        }
    }

    private static func localizedMessage(for code: String) -> String {
        switch code {
        case "INVOCATION_INVALID":
            "Tautan acara tidak valid atau sudah dicabut."
        case "EVENT_FULL":
            "Kapasitas acara sudah penuh."
        case "EVENT_UNAVAILABLE", "BOOKING_NOT_PROCESSABLE":
            "Acara atau booking sudah tidak tersedia."
        case "RATE_LIMITED":
            "Terlalu banyak percobaan. Coba lagi nanti."
        case "BOOKING_CREDENTIALS_INVALID":
            "ID booking atau nomor telepon tidak cocok."
        case "PUBLIC_BOOKING_DISABLED":
            "Booking sedang dinonaktifkan sementara."
        case "AUTH_REQUIRED", "AUTH_INVALID":
            "Sesi login tidak valid. Silakan masuk kembali."
        default:
            "Permintaan gagal (\(code))."
        }
    }
}

struct PublicEventDTO: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let status: EventStatusCode
    let availability: EventAvailabilityCode
    let startAt: Date
    let endAt: Date
    let timezoneName: String
    let operationalDays: [Int]
    let opensAtLocal: String
    let closesAtLocal: String
    let locationName: String
    let locationAddress: String
    let latitude: Double
    let longitude: Double
    let capacityGrams: Int64
    let receivedWeightGrams: Int64
    let bannerObjectPath: String
    let receiverName: String
    let receiverPhone: String
    let receiverAddress: String
    let criteria: [EventCriterionCode]
    let version: Int64
    let schemaVersion: Int?
    let capturedAt: Date?
}

struct PublicLegalDTO: Codable, Equatable, Sendable {
    let termsVersion: String
    let termsURL: URL
    let privacyVersion: String
    let privacyURL: URL

    enum CodingKeys: String, CodingKey {
        case termsVersion
        case termsURL = "termsUrl"
        case privacyVersion
        case privacyURL = "privacyUrl"
    }
}

struct ResolveEventData: Decodable, Equatable, Sendable {
    let event: PublicEventDTO
    let legal: PublicLegalDTO
    let serverTime: Date
    let cacheMaxAgeSeconds: Int
}

struct BookingItemRequest: Encodable, Equatable, Sendable {
    let ordinal: Int
    let passed: Bool
    let scannerModelVersion: String
    let metadata: [String: String]
}

struct CreateBookingRequest: Encodable, Equatable, Sendable {
    let invocationToken: String
    let donorName: String
    let phone: String
    let estimatedWeightGrams: Int64
    let itemCount: Int
    let items: [BookingItemRequest]
    let shippingMethod: ShippingMethodCode
    let scanModelVersion: String
    let termsVersion: String
    let privacyVersion: String
}

struct CreateBookingData: Decodable, Equatable, Sendable {
    let bookingId: String
    let status: BookingStatusCode
    let expiresAt: Date
    let qrToken: String
    let qrPayload: URL
    let labelSnapshot: PublicEventDTO
    let idempotentReplay: Bool
}

struct DonorVerificationData: Decodable, Equatable, Sendable {
    let accessToken: String
    let expiresIn: Int
}

struct DonorBookingStatusData: Decodable, Equatable, Sendable {
    let publicBookingId: String
    let status: BookingStatusCode
    let event: PublicEventDTO
    let expiresAt: Date
    let processedAt: Date?
    let condition: String?
    let rejectionReason: String?
}

struct ResolvedQRBooking: Decodable, Equatable, Sendable {
    let bookingId: UUID
    let publicBookingId: String
    let status: BookingStatusCode
    let estimatedWeightGrams: Int64
    let itemCount: Int
    let shippingMethod: ShippingMethodCode
    let eventSnapshot: PublicEventDTO
    let donorName: String
    let donorPhone: String
}

struct ReceptionDecisionData: Decodable, Equatable, Sendable {
    let bookingId: UUID
    let publicBookingId: String
    let status: BookingStatusCode
    let receivedWeightGrams: Int64
    let capacityGrams: Int64
    let capacityFull: Bool
}

struct PublishEventData: Decodable, Equatable, Sendable {
    let invocationURL: URL

    enum CodingKeys: String, CodingKey {
        case invocationURL = "invocationUrl"
    }
}

struct RecapData: Decodable, Equatable, Sendable {
    let totalAcceptedWeightGrams: Int64
    let acceptedBookingCount: Int64
    let rejectedBookingCount: Int64
    let uniqueDonorCount: Int64
    let completedEventCount: Int64
}
