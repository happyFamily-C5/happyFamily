import Foundation
@testable import happyFamily
import Testing
import UIKit

@Suite("Donor booking consent", .serialized)
@MainActor
struct DonationViewModelTests {
    @Test("personal info advances only after terms are accepted")
    func personalInfoRequiresAcceptedTerms() async throws {
        let harness = try DonationHarness()
        defer { harness.cleanup() }

        await harness.model.start(eventId: harness.eventId)

        #expect(!harness.model.canProceedFromPersonalInfo)
        harness.model.agreedToTerms = true
        #expect(harness.model.canProceedFromPersonalInfo)
    }

    @Test("accepted booking always submits direct shipping")
    func acceptedBookingUsesDirectShipping() async throws {
        let harness = try DonationHarness()
        defer { harness.cleanup() }

        await harness.model.start(eventId: harness.eventId)
        harness.model.agreedToTerms = true
        harness.model.clothingItems = [
            ClothingItem(
                image: UIImage(),
                isPassed: true,
                scannerModelVersion: "accessory-head-v1",
                metadata: [:]
            ),
        ]

        #expect(await harness.model.createBooking())
        #expect(harness.client.lastBooking?.shippingMethod == .direct)
    }
}

@Suite("Admin QR scanner state")
@MainActor
struct QRScannerStateTests {
    @Test("scanner clears a previous result before scanning again")
    func scannerClearsPreviousResult() {
        let cameraManager = CameraManager()
        let scanner = QRScannerViewModel(cameraManager: cameraManager)

        cameraManager.onQRCodeDetected?(String(repeating: "q", count: 43))
        #expect(scanner.result != nil)

        scanner.prepareForNextScan()

        #expect(scanner.result == nil)
        #expect(scanner.actualWeight == 1.0)
    }
}

@MainActor
private final class DonationHarness {
    let eventId = UUID()
    let client: DonationAccountClient
    let model: DonationViewModel

    private let defaults: UserDefaults
    private let defaultsSuite: String

    init() throws {
        defaultsSuite = "DonationViewModelTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: defaultsSuite))
        client = try DonationAccountClient(eventId: eventId)
        model = DonationViewModel(
            accountClient: client,
            attemptStore: BookingAttemptStore(defaults: defaults),
            backendBaseURL: nil
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: defaultsSuite)
    }
}

@MainActor
private final class DonationAccountClient: AccountBackendServing, @unchecked Sendable {
    let detail: DonorEventDetail
    private(set) var lastBooking: AccountBookingBody?

    init(eventId: UUID) throws {
        let json: [String: Any] = [
            "id": eventId.uuidString,
            "name": "Acara Uji",
            "description": "Deskripsi",
            "status": "ongoing",
            "start_at": "2026-09-10T00:00:00Z",
            "end_at": "2026-09-11T00:00:00Z",
            "timezone_name": "Asia/Jakarta",
            "location_name": "Jakarta",
            "location_address": "Jl. Uji",
            "latitude": -6.2,
            "longitude": 106.8,
            "capacity_grams": 10000,
            "received_weight_grams": 0,
            "reserved_weight_grams": 0,
            "used_weight_grams": 0,
            "max_donation_per_user_grams": 5000,
            "banner_object_path": NSNull(),
            "receiver_name": "Penerima",
            "receiver_phone": "+6281234567890",
            "receiver_address": "Jl. Penerima",
            "organization_name": "Organisasi",
            "organization_logo_object_path": NSNull(),
            "distance_km": 1.0,
            "criteria": ["cotton"],
            "availability": [
                "bookable": true,
                "available_weight_grams": 10000,
            ],
            "already_booked": false,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        detail = try BackendJSON.decoder().decode(DonorEventDetail.self, from: data)
    }

    func myProfile() async throws -> AccountProfileData {
        AccountProfileData(
            id: UUID(),
            role: .donor,
            displayName: "Donor Uji",
            phoneE164: "+6281234567890",
            address: nil,
            recommendationLocationLabel: nil,
            avatarObjectPath: nil
        )
    }

    func eventDetail(id _: UUID) async throws -> DonorEventDetail {
        detail
    }

    func createBooking(
        eventId _: UUID,
        booking: AccountBookingBody,
        idempotencyKey _: String
    ) async throws -> CreateBookingResult {
        lastBooking = booking
        return CreateBookingResult(
            bookingId: UUID(),
            publicBookingId: "KPL-TEST-00001",
            status: .waiting,
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            eventSnapshot: detail.event,
            qrToken: String(repeating: "q", count: 43),
            idempotentReplay: false
        )
    }

    func completeOnboarding(role _: AccountRoleCode) async throws -> AccountOnboardingData {
        throw BackendError.configuration("unused in donation tests")
    }

    func updateProfile(_: AccountProfileUpdate) async throws -> AccountProfileData {
        throw BackendError.configuration("unused in donation tests")
    }

    func updateWorkspace(_: AccountWorkspaceUpdate) async throws {
        throw BackendError.configuration("unused in donation tests")
    }

    func requestEmailChange(email _: String) async throws -> AccountEmailChangeData {
        throw BackendError.configuration("unused in donation tests")
    }

    func deleteAccount() async throws {
        throw BackendError.configuration("unused in donation tests")
    }

    func dashboard() async throws -> DonorDashboardData {
        throw BackendError.configuration("unused in donation tests")
    }

    func myBookings() async throws -> [DonorBookingListItem] {
        throw BackendError.configuration("unused in donation tests")
    }

    func bookingDetail(id _: UUID) async throws -> DonorBookingDetail {
        throw BackendError.configuration("unused in donation tests")
    }

    func donationHistory(limit _: Int, cursor _: String?) async throws -> HistoryPage {
        throw BackendError.configuration("unused in donation tests")
    }

    func eventHistory(terminal _: Bool?, limit _: Int, cursor _: String?) async throws -> HistoryPage {
        throw BackendError.configuration("unused in donation tests")
    }

    func cancelBooking(id _: UUID, idempotencyKey _: String) async throws -> CancelBookingResult {
        throw BackendError.configuration("unused in donation tests")
    }
}
