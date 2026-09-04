import SwiftUI
import CoreLocation

#Preview {
    EditEventView(
        event: AdminEvent(
            name: "Ecotoday | drop your unused shirt",
            description: "drop your unused shirt",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
            locationName: "EcoTouch Office",
            locationAddress: "Duren Selatan, Jakarta Barat",
            coordinate: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
            operationalMode: "Hari kerja",
            activeDays: [true, true, true, true, true, false, false],
            startTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
            endTime: Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date(),
            donationCriteria: ["Katun", "Linen", "Wol", "Tencel", "Rayon"],
            capacityKg: 500,
            collectedKg: 250,
            bannerImageData: nil
        )
    ) { _ in }
}
