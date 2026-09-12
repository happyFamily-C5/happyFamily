import CoreLocation
import Foundation

/// Labels MUST stay identical to the chip lists in CreatingView and
/// EditEventView — selection is matched by string.
extension EventCriterionCode {
    var uiLabel: String {
        switch self {
        case .cotton: "Katun"
        case .linen: "Linen"
        case .rayon: "Rayon"
        case .wool: "Wol"
        case .tencel: "Tencel"
        case .silk: "Sutra"
        case .nonStretch: "Tidak Elastis"
        case .denim: "Denim"
        case .noLace: "Tidak berenda"
        case .polyester: "Poliester"
        }
    }

    static var uiLabels: [String] {
        allCases.map(\.uiLabel)
    }

    static func from(uiLabel: String) -> EventCriterionCode? {
        allCases.first { $0.uiLabel == uiLabel }
    }
}

/// Bridges the dashboard's UI model to the backend admin model. Wire days are
/// ISO 1=Monday..7=Sunday; the UI indexes Monday-first into `activeDays`.
extension AdminEvent {
    init(backend: BackendAdminEvent) {
        let coordinate: CLLocationCoordinate2D? = if let latitude = backend.latitude, let longitude = backend.longitude {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            nil
        }
        self.init(
            id: backend.id,
            name: backend.name,
            description: backend.description ?? "",
            startDate: backend.startDate,
            endDate: backend.endDate,
            locationName: backend.locationName ?? "",
            locationAddress: backend.locationAddress ?? "",
            coordinate: coordinate,
            operationalMode: Self.operationalMode(for: backend.operationalDays),
            activeDays: (0 ..< 7).map { backend.operationalDays.contains($0 + 1) },
            startTime: Self.time(from: backend.opensAtLocal, fallbackHour: 8),
            endTime: Self.time(from: backend.closesAtLocal, fallbackHour: 17),
            donationCriteria: backend.criteria.map(\.uiLabel),
            capacityKg: backend.capacityKg,
            collectedKg: backend.collectedKg,
            status: backend.status,
            bannerImageData: backend.bannerImageData,
            bannerObjectPath: backend.bannerObjectPath,
            maxDonationPerUserKg: backend.maxDonationPerUserKg
        )
    }

    /// Server rejects publish for any timezone other than Asia/Jakarta, and
    /// schedule times are stored as local wall-clock strings.
    func toBackendAdminEvent() -> BackendAdminEvent {
        BackendAdminEvent(
            id: id,
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            capacityKg: capacityKg,
            collectedKg: collectedKg,
            bannerImageData: bannerImageData,
            bannerObjectPath: bannerObjectPath,
            status: status,
            timezoneName: "Asia/Jakarta",
            operationalDays: activeDays.enumerated().compactMap { $0.element ? $0.offset + 1 : nil },
            opensAtLocal: Self.localTimeString(from: startTime),
            closesAtLocal: Self.localTimeString(from: endTime),
            locationName: locationName,
            locationAddress: locationAddress,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            criteria: donationCriteria.compactMap(EventCriterionCode.from(uiLabel:)),
            maxDonationPerUserKg: maxDonationPerUserKg
        )
    }

    private static func operationalMode(for operationalDays: [Int]) -> String {
        let days = Set(operationalDays)
        if days == Set([1, 2, 3, 4, 5]) {
            return "Hari Kerja"
        }
        if days == Set([6, 7]) {
            return "Akhir Pekan"
        }
        if days.count == 7 {
            return "Setiap Hari"
        }
        return "Hari Kustom"
    }

    private static func time(from local: String, fallbackHour: Int) -> Date {
        let parts = local.split(separator: ":").compactMap { Int($0) }
        let hour = parts.first ?? fallbackHour
        let minute = parts.count > 1 ? parts[1] : 0
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(hour: hour, minute: minute))
            ?? calendar.date(from: DateComponents(hour: fallbackHour, minute: 0))
            ?? Date()
    }

    private static func localTimeString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(
            format: "%02d:%02d:00",
            components.hour ?? 0,
            components.minute ?? 0
        )
    }
}
