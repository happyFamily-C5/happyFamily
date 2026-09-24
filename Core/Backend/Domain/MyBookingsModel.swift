import Foundation
import Observation

/// Donor "Pesanan Saya" surface: `account:my_bookings` list, typed
/// `account:booking_detail` with timeline and QR token, and idempotent
/// cancellation. QR tokens are mirrored into the Keychain only.
@MainActor
@Observable
final class MyBookingsModel {
    private(set) var bookings: [DonorBookingListItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private(set) var detail: DonorBookingDetail?
    private(set) var isLoadingDetail = false
    var detailError: String?

    private(set) var isCancelling = false
    var cancelError: String?

    private let accountClient: (any AccountBackendServing)?
    private let backendBaseURL: URL?

    init(
        accountClient: (any AccountBackendServing)?,
        backendBaseURL: URL? = BackendDependencies.backendBaseURL()
    ) {
        self.accountClient = accountClient
        self.backendBaseURL = backendBaseURL
    }

    func load() async {
        guard let accountClient else {
            errorMessage = "Backend belum dikonfigurasi"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            bookings = try await accountClient.myBookings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDetail(bookingId: UUID) async {
        guard let accountClient else {
            detailError = "Backend belum dikonfigurasi"
            return
        }
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        do {
            let loaded = try await accountClient.bookingDetail(id: bookingId)
            detail = loaded
            detailError = nil
            if let qrToken = loaded.qrToken {
                try? QRTokenKeychain.save(qrToken, bookingId: bookingId)
            }
        } catch {
            detailError = error.localizedDescription
        }
    }

    /// Cancellation is idempotent per donor + booking; the deterministic
    /// key makes a retry after any transport failure replay the same
    /// server decision.
    @discardableResult
    func cancel(bookingId: UUID) async -> Bool {
        guard let accountClient, isCancelling == false else { return false }
        isCancelling = true
        defer { isCancelling = false }
        do {
            let result = try await accountClient.cancelBooking(
                id: bookingId,
                idempotencyKey: "cancel-booking-\(bookingId.uuidString)"
            )
            bookings.removeAll { $0.bookingId == bookingId }
            if detail?.id == bookingId {
                detail = nil
            }
            try? QRTokenKeychain.delete(bookingId: bookingId)
            cancelError = nil
            return result.status == .cancelled
        } catch {
            cancelError = error.localizedDescription
            return false
        }
    }

    /// Public banner URL for a booking's event snapshot. Cosmetic: nil on
    /// any missing piece, never fails the list.
    func bannerURL(for booking: DonorBookingListItem) -> URL? {
        EventBannerURLBuilder.makeURL(
            baseURL: backendBaseURL,
            objectPath: booking.event.bannerObjectPath
        )
    }
}
