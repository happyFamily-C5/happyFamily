//
//  DonationViewModel.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import CoreImage.CIFilterBuiltins
import SwiftUI

/// Drives the donor donation flow against the authenticated account API.
/// Donor identity comes from the profile (the server encrypts it), the event
/// and the booking submission is idempotent through a persisted attempt key.
@MainActor
@Observable
final class DonationViewModel {
    var agreedToTerms: Bool = false
    var clothingItems: [ClothingItem] = []

    private(set) var displayName: String = ""
    private(set) var phoneE164: String = ""
    private(set) var isProfileComplete = false

    private(set) var detail: DonorEventDetail?
    private(set) var isLoadingDetail = false
    private(set) var booking: CreateBookingResult?
    private(set) var isCreatingBooking = false
    var errorMessage: String?

    private let accountClient: (any AccountBackendServing)?
    private let attemptStore: BookingAttemptStore

    private let backendBaseURL: URL?
    private var loadedEventId: UUID?

    nonisolated init(
        accountClient: (any AccountBackendServing)? = BackendDependencies.accountClientOrDefault(),
        attemptStore: BookingAttemptStore = BookingAttemptStore(),
        backendBaseURL: URL? = BackendDependencies.backendBaseURL()
    ) {
        self.accountClient = accountClient
        self.attemptStore = attemptStore
        self.backendBaseURL = backendBaseURL
    }

    var displayBookingID: String {
        booking?.publicBookingId ?? ""
    }

    func bannerURL() -> URL? {
        EventBannerURLBuilder.makeURL(
            baseURL: backendBaseURL,
            objectPath: detail?.event.bannerObjectPath
        )
    }

    // MARK: - Flow entry

    /// Entry point from the event detail CTA. Loads the event detail and the
    /// profile summary the flow displays instead of collecting PII locally.
    func start(eventId: UUID) async {
        guard loadedEventId != eventId || detail == nil else { return }
        loadedEventId = eventId
        resetDonationState()
        await load(eventId: eventId)
    }

    func retryLoadingEvent() async {
        guard let loadedEventId else { return }
        await load(eventId: loadedEventId)
    }

    private func load(eventId: UUID) async {
        guard let accountClient else {
            errorMessage = "Backend belum dikonfigurasi"
            return
        }
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        async let detailResult = accountClient.eventDetail(id: eventId)
        async let profileResult = accountClient.myProfile()
        do {
            detail = try await detailResult
            let profile = try await profileResult
            displayName = profile.displayName
            phoneE164 = profile.phoneE164 ?? ""
            isProfileComplete = !profile.displayName.isEmpty && profile.phoneE164 != nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Step validation

    var canProceedFromPersonalInfo: Bool {
        isProfileComplete && agreedToTerms
    }

    var canProceedFromCapture: Bool {
        !clothingItems.isEmpty
    }

    var canProceedFromReview: Bool {
        clothingItems.contains { $0.isPassed }
    }

    // MARK: - Booking submission

    /// Submits `account:create_booking` with the persisted idempotency
    /// attempt. A retry after failure (or process death) reuses the same key
    /// and payload; a success clears the attempt and stores the returned QR
    /// token in the Keychain only.
    func createBooking() async -> Bool {
        guard let detail, !isCreatingBooking else { return false }
        guard detail.availability.bookable else {
            errorMessage = "Acara tidak dapat dipesan saat ini."
            return false
        }
        guard agreedToTerms else {
            errorMessage = "Setujui syarat dan ketentuan sebelum melanjutkan."
            return false
        }
        let passedItems = clothingItems.filter(\.isPassed)
        guard !passedItems.isEmpty else { return false }

        let body = AccountBookingBody(
            estimatedWeightGrams: Int64(passedItems.count * 500),
            itemCount: passedItems.count,
            items: passedItems.enumerated().map { index, item in
                AccountBookingItem(
                    ordinal: index,
                    passed: true,
                    scannerModelVersion: item.scannerModelVersion,
                    metadata: item.metadata
                )
            },
            shippingMethod: .direct,
            scanModelVersion: Self.scanModelVersion(from: passedItems)
        )

        let payload: Data
        do {
            payload = try bookingBodyPayload(body)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        let attempt = attemptStore.resolveAttempt(eventId: detail.event.id, payload: payload)

        isCreatingBooking = true
        defer { isCreatingBooking = false }
        do {
            guard let accountClient else {
                throw BackendError.configuration("account create booking is unavailable")
            }
            let result = try await accountClient.createBooking(
                eventId: detail.event.id,
                booking: body,
                idempotencyKey: attempt.idempotencyKey
            )
            booking = result
            attemptStore.clear()
            try? QRTokenKeychain.save(result.qrToken, bookingId: result.bookingId)
            errorMessage = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            // Keep the stored attempt: retrying replays the identical request.
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func scanModelVersion(from items: [ClothingItem]) -> String {
        var version = Set(items.map(\.scannerModelVersion)).sorted().joined(separator: "+")
        if version.count > 80 {
            version = String(version.prefix(80))
        }
        return version.isEmpty ? "accessory-head-v1" : version
    }

    func resetDonationState() {
        agreedToTerms = false
        clothingItems = []
        booking = nil
        errorMessage = nil
    }
}

func generateQRCode(from string: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.correctionLevel = "H"
    filter.message = Data(string.utf8)

    if let outputImage = filter.outputImage {
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    return UIImage(systemName: "xmark") ?? UIImage()
}
