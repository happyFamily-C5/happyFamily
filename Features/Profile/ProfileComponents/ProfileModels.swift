import CoreLocation
import Foundation
import SwiftUI
import UIKit

struct AdminProfile {
    var companyName: String
    var companyAddress: String
    var phoneNumber: String
    var email: String
    var imageData: Data?

    /// Storage path of the workspace logo in the `workspace-logos` bucket,
    /// kept so an untouched logo is never rewritten (or wiped by "").
    var logoObjectPath: String?

    static let defaultProfile = AdminProfile(
        companyName: "EcoTouch Office",
        companyAddress: "Jl. Arjuna Utara No. 14D,\nTanjung Duren Selatan\nJakarta Barat",
        phoneNumber: "",
        email: "",
        imageData: nil,
        logoObjectPath: nil
    )
}

struct DonorProfile {
    var fullName: String
    var address: String
    var imageData: Data?
    /// Server identity of the signed-in donor; needed for the private-bucket
    /// avatar upload path (`<auth-user-id>/<file>`). nil only in previews.
    var id: UUID?
    var phoneE164: String = ""
    /// Bucket-relative avatar path owned by the server; "" removes it.
    var avatarObjectPath: String = ""

    init(
        fullName: String,
        address: String,
        imageData: Data?,
        id: UUID? = nil,
        phoneE164: String = "",
        avatarObjectPath: String = ""
    ) {
        self.fullName = fullName
        self.address = address
        self.imageData = imageData
        self.id = id
        self.phoneE164 = phoneE164
        self.avatarObjectPath = avatarObjectPath
    }

    static let defaultProfile = DonorProfile(
        fullName: "Yuan Dimianta",
        address: "Jl. Kutilang 9-2, Palmerah, Kec. Palmerah, Kota Jakarta Barat.",
        imageData: nil
    )
}

enum ProfileCompletionPolicy {
    static func canCreateEvent(_ profile: AdminProfile) -> Bool {
        required(profile.companyName)
            && required(profile.companyAddress)
            && required(profile.phoneNumber)
            && required(profile.email)
    }

    static func canDonate(_ profile: DonorProfile) -> Bool {
        required(profile.fullName) && required(profile.phoneE164)
    }

    private static func required(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: Donor's donation history — events they've personally contributed to, with the weight they gave

struct DonorDonation: Identifiable {
    let id = UUID()
    let eventName: String
    let dateRangeText: String
    let weightText: String
    let bannerImageData: Data?

    var bannerImage: Image {
        if let bannerImageData, let uiImage = UIImage(data: bannerImageData) {
            return Image(uiImage: uiImage)
        }
        return Image("EventBannerPlaceholder")
    }

    static let sampleData: [DonorDonation] = [
        DonorDonation(
            eventName: "Ecoday | drop your unused shirt",
            dateRangeText: "9 Sept - 16 Sept 2026",
            weightText: "4.3 kg",
            bannerImageData: nil
        ),
        DonorDonation(
            eventName: "Give Clothes a Second Life",
            dateRangeText: "9 Sept - 16 Sept 2026",
            weightText: "3.8 kg",
            bannerImageData: nil
        ),
        DonorDonation(eventName: "Textile Rescue Day", dateRangeText: "9 Sept - 16 Sept 2026", weightText: "4.9 kg", bannerImageData: nil),
        DonorDonation(eventName: "ReWear & Recycle", dateRangeText: "9 Sept - 16 Sept 2026", weightText: "4.1 kg", bannerImageData: nil),
        DonorDonation(
            eventName: "From Closet to Impact",
            dateRangeText: "9 Sept - 16 Sept 2026",
            weightText: "3.2 kg",
            bannerImageData: nil
        ),
        DonorDonation(
            eventName: "Old Clothes, New Purpose",
            dateRangeText: "9 Sept - 16 Sept 2026",
            weightText: "4.2 kg",
            bannerImageData: nil
        ),
        DonorDonation(
            eventName: "Don't Trash Your Textile",
            dateRangeText: "9 Sept - 16 Sept 2026",
            weightText: "4.3 kg",
            bannerImageData: nil
        ),
    ]
}

enum ProfileHistoryBookingDummyData {

    static let events: [BookingHistoryItem] = [
        BookingHistoryItem(
            bookingId: UUID(),
            publicBookingId: "SS-76329",
            status: .recycled,
            estimatedWeightGrams: 4300,
            actualWeightGrams: 4300,
            event: BookingEventSnapshot(
                id: UUID(),
                name: "Ecoday | drop your unused shirt",
                status: .completed,
                startAt: Date(),
                endAt: Date(),
                locationName: "EcoTouch Office",
                bannerObjectPath: nil
            ),
            createdAt: Date(),
            statusUpdatedAt: Date()
        ),

        BookingHistoryItem(
            bookingId: UUID(),
            publicBookingId: "SS-76330",
            status: .recycled,
            estimatedWeightGrams: 3800,
            actualWeightGrams: 3800,
            event: BookingEventSnapshot(
                id: UUID(),
                name: "Give Clothes a Second Life",
                status: .completed,
                startAt: Date(),
                endAt: Date(),
                locationName: "EcoTouch Office",
                bannerObjectPath: nil
            ),
            createdAt: Date(),
            statusUpdatedAt: Date()
        )
    ]
}

enum ProfileDonationHistoryDummyData {

    static let donations: [BookingHistoryItem] = [
        BookingHistoryItem(
            bookingId: UUID(),
            publicBookingId: "SS-76329",
            status: .recycled,
            estimatedWeightGrams: 4300,
            actualWeightGrams: 4300,
            event: BookingEventSnapshot(
                id: UUID(),
                name: "Yuan Dimianta",
                status: .completed,
                startAt: Date(),
                endAt: Date(),
                locationName: "EcoTouch Office",
                bannerObjectPath: nil
            ),
            createdAt: Date().addingTimeInterval(-3600),
            statusUpdatedAt: Date()
        ),

        BookingHistoryItem(
            bookingId: UUID(),
            publicBookingId: "SS-76330",
            status: .recycled,
            estimatedWeightGrams: 3800,
            actualWeightGrams: 3800,
            event: BookingEventSnapshot(
                id: UUID(),
                name: "Calzy Akmal",
                status: .completed,
                startAt: Date(),
                endAt: Date(),
                locationName: "EcoTouch Office",
                bannerObjectPath: nil
            ),
            createdAt: Date().addingTimeInterval(-3600),
            statusUpdatedAt: Date()
        ),

        BookingHistoryItem(
            bookingId: UUID(),
            publicBookingId: "SS-76331",
            status: .processed,
            estimatedWeightGrams: 4900,
            actualWeightGrams: nil,
            event: BookingEventSnapshot(
                id: UUID(),
                name: "Sasha Grey",
                status: .ongoing,
                startAt: Date(),
                endAt: Date(),
                locationName: "EcoTouch Office",
                bannerObjectPath: nil
            ),
            createdAt: Date(),
            statusUpdatedAt: Date()
        )
    ]
}
