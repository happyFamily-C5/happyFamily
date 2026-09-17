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
    case processed
    case recycled
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
    case invalidResponse
    case transport(String)
    case decoding(String)
    case api(code: String, retryable: Bool, fieldErrors: [String: String], requestId: UUID?)

    var errorDescription: String? {
        switch self {
        case let .configuration(key):
            return "Konfigurasi backend \(key) belum tersedia."
        case .invalidResponse:
            return "Respons server tidak valid."
        case .transport:
            return "Koneksi ke server gagal. Coba lagi."
        case .decoding:
            return "Data dari server tidak dapat dibaca."
        case let .api(code, _, fieldErrors, _):
            if code == "EVENT_PUBLISH_FIELDS_REQUIRED", !fieldErrors.isEmpty {
                let details = fieldErrors
                    .sorted { $0.key < $1.key }
                    .map { "• \($0.value)" }
                    .joined(separator: "\n")
                return "Data acara yang perlu dilengkapi:\n\(details)"
            }
            return Self.localizedMessage(for: code)
        }
    }

    private static let localizedMessages: [String: String] = [
        "INVOCATION_INVALID": "Tautan acara tidak valid atau sudah dicabut.",
        "EVENT_FULL": "Kapasitas acara sudah penuh.",
        "EVENT_UNAVAILABLE": "Acara atau booking sudah tidak tersedia.",
        "BOOKING_NOT_PROCESSABLE": "Acara atau booking sudah tidak tersedia.",
        "BOOKING_NOT_CANCELLABLE": "Booking hanya dapat dibatalkan saat masih menunggu.",
        "DONATION_LIMIT_EXCEEDED": "Berat donasi melewati batas yang ditetapkan acara.",
        "ROLE_FORBIDDEN": "Akun ini tidak memiliki akses untuk tindakan tersebut.",
        "ROLE_IMMUTABLE": "Akun ini tidak memiliki akses untuk tindakan tersebut.",
        "RATE_LIMITED": "Terlalu banyak percobaan. Coba lagi nanti.",
        "BOOKING_CREDENTIALS_INVALID": "ID booking atau nomor telepon tidak cocok.",
        "PHONE_INVALID": "Masukkan nomor WhatsApp Indonesia yang valid, misalnya 0812 3456 7890.",
        "AUTH_REQUIRED": "Sesi login tidak valid. Silakan masuk kembali.",
        "AUTH_INVALID": "Sesi login tidak valid. Silakan masuk kembali.",
        "ACCOUNT_DELETE_FAILED": "Akun belum dapat dihapus. Coba lagi atau hubungi dukungan.",
        "WORKSPACE_PROFILE_INCOMPLETE": "Lengkapi profil workspace sebelum melanjutkan.",
        "EVENT_PUBLISH_FIELDS_REQUIRED": "Lengkapi semua data acara sebelum dipublikasikan.",
        "INVALID_DONATION_LIMIT": "Limit donasi per donatur tidak valid.",
        "IDEMPOTENCY_CONFLICT": "Perubahan bentrok dengan permintaan sebelumnya. Muat ulang lalu coba lagi.",
        "IDEMPOTENCY_INCOMPLETE": "Sinkronisasi belum selesai. Coba lagi.",
        "EVENT_NOT_CANCELLABLE": "Acara sudah tidak dapat dibatalkan.",
        "DRAFT_HAS_BOOKINGS": "Draf memiliki donasi terkait dan tidak dapat dihapus.",
        "BANNER_REJECTED": "Upload gambar tidak diizinkan. Gunakan JPEG atau PNG.",
        "BANNER_DIMENSIONS_INVALID": "Dimensi gambar terlalu besar. Pilih gambar lain atau coba kembali.",
        "BANNER_DIMENSION_INVALID": "Dimensi gambar terlalu besar. Pilih gambar lain atau coba kembali.",
        "PROFILE_MEDIA_REJECTED": "Upload gambar ditolak oleh penyimpanan. Gunakan JPEG atau PNG berukuran maksimal 5 MB.",
        "PROFILE_MEDIA_FORBIDDEN": "Anda tidak memiliki izin untuk mengunggah gambar ini. Muat ulang profil lalu coba lagi.",
        "BANNER_TOO_LARGE": "Ukuran gambar melebihi 5 MB. Kompres atau pilih gambar lain.",
        "PROFILE_MEDIA_TOO_LARGE": "Ukuran gambar melebihi 5 MB. Kompres atau pilih gambar lain.",
    ]

    private static func localizedMessage(for code: String) -> String {
        localizedMessages[code] ?? "Permintaan gagal (\(code))."
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
    /// Older deployments return only the published event. Treat a missing URL
    /// as a successful publish so the client can refresh server truth instead
    /// of reporting a decoding failure after the transaction committed.
    let invocationURL: URL?

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

struct AdminRecapData: Decodable, Equatable, Sendable {
    struct Month: Decodable, Equatable, Sendable {
        let acceptedWeightGrams: Int64
        let acceptedCount: Int64
        let uniqueDonorCount: Int64
    }

    struct RecentDonation: Decodable, Equatable, Sendable {
        let bookingId: UUID
        let publicBookingId: String
        let donorName: String?
        let actualWeightGrams: Int64
        let eventName: String
        let receivedAt: Date
    }

    let month: Month
    let recentDonations: [RecentDonation]
}

/// Snapshot of the event embedded in admin booking-history rows. The history
/// RPC returns a partial event (no availability/version) and its
/// `banner_object_path` can be null, so this is intentionally not
/// `PublicEventDTO`.
struct BookingEventSnapshot: Decodable, Equatable, Sendable {
    let id: UUID
    let name: String?
    let status: EventStatusCode?
    let startAt: Date?
    let endAt: Date?
    let locationName: String?
    let bannerObjectPath: String?
}

struct BookingHistoryItem: Decodable, Equatable, Sendable, Identifiable {
    let bookingId: UUID
    let publicBookingId: String
    let status: BookingStatusCode
    let estimatedWeightGrams: Int64
    let actualWeightGrams: Int64?
    let event: BookingEventSnapshot
    let createdAt: Date
    let statusUpdatedAt: Date?

    var id: UUID {
        bookingId
    }
}

struct HistoryPage: Decodable, Equatable, Sendable {
    let items: [BookingHistoryItem]
    let nextCursor: String?
}

/// Row shape of `event_user_json` (admin event responses).
struct EventRecordDTO: Decodable, Equatable, Sendable {
    let id: UUID
    let name: String?
    let description: String?
    let status: EventStatusCode
    let startAt: Date?
    let endAt: Date?
    let timezoneName: String?
    let operationalDays: [Int]?
    let opensAtLocal: String?
    let closesAtLocal: String?
    let locationName: String?
    let locationAddress: String?
    let latitude: Double?
    let longitude: Double?
    let capacityGrams: Int64?
    let receivedWeightGrams: Int64
    let bannerObjectPath: String?
    let receiverName: String?
    let receiverPhone: String?
    let receiverAddress: String?
    let criteria: [EventCriterionCode]
    let maxDonationPerUserGrams: Int64?
    let version: Int64?
}

/// Body of `upsert_event_draft` on `POST /operations`. Receiver fields are a
/// workspace snapshot the server owns, so they are never sent. Optional keys
/// are omitted when nil and the server then preserves its current value.
struct EventDraftPayload: Encodable, Sendable {
    let name: String
    let description: String?
    let startAt: String
    let endAt: String
    let timezoneName: String
    let operationalDays: [Int]
    let opensAtLocal: String
    let closesAtLocal: String
    let locationName: String?
    let locationAddress: String?
    let locationCountryCode: String
    let latitude: Double?
    let longitude: Double?
    let capacityGrams: Int64
    let bannerObjectPath: String?
    let maxDonationPerUserGrams: Int64?
    let criteria: [EventCriterionCode]

    init(event: BackendAdminEvent) {
        name = event.name
        description = event.description
        startAt = event.startDate.ISO8601Format()
        endAt = event.endDate.ISO8601Format()
        timezoneName = event.timezoneName
        operationalDays = event.operationalDays
        opensAtLocal = event.opensAtLocal
        closesAtLocal = event.closesAtLocal
        locationName = event.locationName
        locationAddress = event.locationAddress
        locationCountryCode = "ID"
        latitude = event.latitude
        longitude = event.longitude
        capacityGrams = Int64(event.capacityKg) * 1000
        bannerObjectPath = event.bannerObjectPath
        maxDonationPerUserGrams = event.maxDonationPerUserKg.map { Int64($0) * 1000 }
        criteria = event.criteria
    }
}

/// Dual-shape response of `cancel_or_delete_event`: a deleted draft returns
/// `action: "draft_deleted"`; a cancelled live event returns a status plus the
/// number of waiting bookings that were cancelled along with it.
struct CancelEventData: Decodable, Equatable, Sendable {
    let eventId: UUID
    let status: EventStatusCode?
    let action: String?
    let cancelledWaitingBookings: Int?
}
