import Foundation

struct AdminEvent: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var description: String?
    var startDate: Date
    var endDate: Date
    var capacityKg: Int
    var collectedKg: Double
    var bannerImageData: Data?
    var bannerObjectPath: String?
    var status: EventStatusCode
    var timezoneName: String
    var operationalDays: [Int]
    var opensAtLocal: String
    var closesAtLocal: String
    var locationName: String?
    var locationAddress: String?
    var latitude: Double?
    var longitude: Double?
    var criteria: [EventCriterionCode]
    var receiverName: String?
    var receiverPhone: String?
    var receiverAddress: String?
    var version: Int64

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        startDate: Date,
        endDate: Date,
        capacityKg: Int,
        collectedKg: Double,
        bannerImageData: Data? = nil,
        bannerObjectPath: String? = nil,
        status: EventStatusCode = .draft,
        timezoneName: String = "Asia/Jakarta",
        operationalDays: [Int] = [],
        opensAtLocal: String = "08:00:00",
        closesAtLocal: String = "17:00:00",
        locationName: String? = nil,
        locationAddress: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        criteria: [EventCriterionCode] = [],
        receiverName: String? = nil,
        receiverPhone: String? = nil,
        receiverAddress: String? = nil,
        version: Int64 = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.capacityKg = capacityKg
        self.collectedKg = collectedKg
        self.bannerImageData = bannerImageData
        self.bannerObjectPath = bannerObjectPath
        self.status = status
        self.timezoneName = timezoneName
        self.operationalDays = operationalDays
        self.opensAtLocal = opensAtLocal
        self.closesAtLocal = closesAtLocal
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.latitude = latitude
        self.longitude = longitude
        self.criteria = criteria
        self.receiverName = receiverName
        self.receiverPhone = receiverPhone
        self.receiverAddress = receiverAddress
        self.version = version
    }

    var progress: Double {
        guard capacityKg > 0 else { return 0 }
        return min(collectedKg / Double(capacityKg), 1)
    }

    var isOngoing: Bool {
        if status == .ongoing {
            return true
        }
        guard status == .draft else { return false }
        return Date.now >= startDate && Date.now <= endDate
    }

    var isUpcoming: Bool {
        status == .upcoming || (status == .draft && startDate > .now)
    }

    var formattedDateRange: String {
        let start = startDate.formatted(.dateTime.month(.wide).day())
        let end = endDate.formatted(.dateTime.month(.wide).day())
        return "\(start) - \(end)".uppercased()
    }
}
