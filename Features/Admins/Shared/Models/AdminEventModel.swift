import CoreLocation
import SwiftUI

// MARK: - Model Pendukung untuk Logika Tanggal Event

struct AdminEvent: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let startDate: Date
    let endDate: Date
    let locationName: String
    let locationAddress: String
    let coordinate: CLLocationCoordinate2D?
    let operationalMode: String
    let activeDays: [Bool]
    let startTime: Date
    let endTime: Date
    let donationCriteria: [String]
    let capacityKg: Int
    var collectedKg: Double

    /// Lifecycle from the server (`list_events` snapshot). Draft-only events
    /// created offline stay `.draft`; publishing flips it locally after the
    /// server call succeeds.
    var status: EventStatusCode = .draft

    /// The cover the organiser picked in CreatingView, kept as Data so the
    /// event stays a plain value type — SwiftUI's Image is not persistable.
    var bannerImageData: Data?

    /// Storage path of the uploaded banner, carried through edits so an
    /// untouched banner keeps pointing at the same object server-side.
    var bannerObjectPath: String?

    /// Per-donor donation limit in kilograms (backend: grams).
    var maxDonationPerUserKg: Int?

    /// The organiser's cover, falling back to the placeholder when they
    /// skipped the picker (the cover is optional in step 1).
    var bannerImage: Image {
        if let bannerImageData, let uiImage = UIImage(data: bannerImageData) {
            return Image(uiImage: uiImage)
        }
        return Image("DummyImageBanner")
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        startDate: Date,
        endDate: Date,
        locationName: String,
        locationAddress: String,
        coordinate: CLLocationCoordinate2D?,
        operationalMode: String,
        activeDays: [Bool],
        startTime: Date,
        endTime: Date,
        donationCriteria: [String],
        capacityKg: Int,
        collectedKg: Double,
        status: EventStatusCode = .draft,
        bannerImageData: Data?,
        bannerObjectPath: String? = nil,
        maxDonationPerUserKg: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.coordinate = coordinate
        self.operationalMode = operationalMode
        self.activeDays = activeDays
        self.startTime = startTime
        self.endTime = endTime
        self.donationCriteria = donationCriteria
        self.capacityKg = capacityKg
        self.collectedKg = collectedKg
        self.status = status
        self.bannerImageData = bannerImageData
        self.bannerObjectPath = bannerObjectPath
        self.maxDonationPerUserKg = maxDonationPerUserKg
    }

    var progress: Double {
        guard capacityKg > 0 else { return 0 }
        return min(collectedKg / Double(capacityKg), 1)
    }

    var isOngoing: Bool {
        switch status {
        case .ongoing:
            return true
        case .draft:
            // Offline drafts keep the legacy date-based placement.
            let today = Date()
            return today >= Calendar.current.startOfDay(for: startDate)
                && today <= Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
        default:
            return false
        }
    }

    var isUpcoming: Bool {
        switch status {
        case .upcoming:
            true
        case .draft:
            startDate > Date()
        default:
            false
        }
    }

    static func statusLabel(_ status: EventStatusCode) -> String {
        switch status {
        case .draft: "Draf"
        case .upcoming: "Akan datang"
        case .ongoing: "Berlangsung"
        case .completed: "Selesai"
        case .closed: "Ditutup"
        case .cancelled: "Dibatalkan"
        }
    }

    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        let startStr = formatter.string(from: startDate).uppercased()
        let endStr = formatter.string(from: endDate).uppercased()
        return "\(startStr) - \(endStr)"
    }

    var formattedTimeInfo: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm"
        return "\(operationalMode) • \(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}
