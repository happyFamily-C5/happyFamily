import Foundation
import CoreLocation

struct AdminProfile {
    var companyName: String
    var companyAddress: String
    var phoneNumber: String
    var email: String
    var imageData: Data?
    
    static let defaultProfile = AdminProfile(
        companyName: "EcoTouch Office",
        companyAddress: "Jl. Arjuna Utara No. 14D,\nTanjung Duren Selatan\nJakarta Barat",
        phoneNumber: "",
        email: "",
        imageData: nil
    )
}

struct RegisterAccountDraft {
    let name: String
    let email: String
    let password: String
}

struct ProfileDonation: Identifiable {
    let id = UUID()
    let donorName: String
    let relativeTime: String
    let weightText: String
    
    static let sampleData: [ProfileDonation] = [
        ProfileDonation(donorName: "Yuan Dimanta", relativeTime: "1 jam yang lalu", weightText: "4.3 kg"),
        ProfileDonation(donorName: "Calzy Akmal", relativeTime: "2 jam yang lalu", weightText: "4.5 kg"),
        ProfileDonation(donorName: "Sasha Grey", relativeTime: "2 jam yang lalu", weightText: "2.3 kg"),
        ProfileDonation(donorName: "Bintang di langit", relativeTime: "3 jam yang lalu", weightText: "3.6 kg"),
        ProfileDonation(donorName: "Hendra Irawan", relativeTime: "3 jam yang lalu", weightText: "4.8 kg"),
        ProfileDonation(donorName: "Hendra Irawan", relativeTime: "3 jam yang lalu", weightText: "4.8 kg"),
        ProfileDonation(donorName: "Hendra Irawan", relativeTime: "3 jam yang lalu", weightText: "4.8 kg")
    ]
}

enum ProfileHistoryDummyData {
    static var completedEvent: AdminEvent {
        AdminEvent(
            name: "Ecoday | drop your unused shirt",
            description: "Drop your unused shirt",
            startDate: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 9)) ?? Date(),
            endDate: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 16)) ?? Date(),
            locationName: "EcoTouch Office",
            locationAddress: "Duren Selatan, Jakarta Barat",
            coordinate: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272),
            operationalMode: "Hari kerja",
            activeDays: [true, true, true, true, true, false, false],
            startTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
            endTime: Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date(),
            donationCriteria: ["Katun", "Linen", "Wol"],
            capacityKg: 500,
            collectedKg: 500,
            bannerImageData: nil
        )
    }
}
