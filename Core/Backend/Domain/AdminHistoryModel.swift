import Foundation
import Observation

/// Loads admin booking histories from `operations:donation_history` /
/// `operations:event_history` and advances booking tracking. Bookings come
/// exclusively from the server; nothing here keeps local booking state.
@MainActor
@Observable
final class AdminHistoryModel {
    /// Bookings that have been received (status accepted/processed/recycled).
    private(set) var donations: [BookingHistoryItem] = []
    /// Bookings from events other than cancelled ones, newest first.
    private(set) var events: [BookingHistoryItem] = []

    private(set) var isLoadingDonations = false
    private(set) var isLoadingEvents = false
    private(set) var isLoadingMoreDonations = false
    private(set) var isLoadingMoreEvents = false

    var donationError: String?
    var eventError: String?

    private var donationCursor: String?
    private var eventCursor: String?

    private let historyRepository: (any ReportRepository)?
    private let receptionRepository: (any ReceptionRepository)?
    private let backendBaseURL: URL?

    init(
        historyRepository: (any ReportRepository)?,
        receptionRepository: (any ReceptionRepository)?,
        backendBaseURL: URL? = BackendDependencies.backendBaseURL()
    ) {
        self.historyRepository = historyRepository
        self.receptionRepository = receptionRepository
        self.backendBaseURL = backendBaseURL
    }

    #if DEBUG
        init(previewDonations: [BookingHistoryItem]) {
            self.historyRepository = nil
            self.receptionRepository = nil
            self.backendBaseURL = BackendDependencies.backendBaseURL()
            self.donations = previewDonations
        }
    #endif

    #if DEBUG
        init(previewEvents: [BookingHistoryItem]) {
            self.historyRepository = nil
            self.receptionRepository = nil
            self.backendBaseURL = BackendDependencies.backendBaseURL()
            self.events = previewEvents
        }
    #endif

    var hasMoreDonations: Bool {
        donationCursor != nil
    }

    var hasMoreEvents: Bool {
        eventCursor != nil
    }

    func bannerURL(for item: BookingHistoryItem) -> URL? {
        EventBannerURLBuilder.makeURL(
            baseURL: backendBaseURL,
            objectPath: item.event.bannerObjectPath
        )
    }

    func loadDonations() async {
        guard let historyRepository, !isLoadingDonations else { return }
        isLoadingDonations = true
        defer { isLoadingDonations = false }
        do {
            let page = try await historyRepository.donationHistory(eventId: nil, cursor: nil)
            donations = page.items
            donationCursor = page.nextCursor
            donationError = nil
        } catch {
            donationError = error.localizedDescription
        }
    }

    func loadMoreDonations() async {
        await loadMore(\.donationCursor) { cursor in
            guard let repository = self.historyRepository else {
                throw BackendError.configuration("operations history is unavailable")
            }
            return try await repository.donationHistory(eventId: nil, cursor: cursor)
        } apply: { page in
            self.donations = Self.appended(self.donations, page.items)
            self.donationError = nil
        } setError: { self.donationError = $0 }
    }

    func loadEvents() async {
        guard let historyRepository, !isLoadingEvents else { return }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            let page = try await historyRepository.eventHistory(eventId: nil, cursor: nil)
            events = page.items
            eventCursor = page.nextCursor
            eventError = nil
        } catch {
            eventError = error.localizedDescription
        }
    }

    func loadMoreEvents() async {
        await loadMore(\.eventCursor) { cursor in
            guard let repository = self.historyRepository else {
                throw BackendError.configuration("operations history is unavailable")
            }
            return try await repository.eventHistory(eventId: nil, cursor: cursor)
        } apply: { page in
            self.events = Self.appended(self.events, page.items)
            self.eventError = nil
        } setError: { self.eventError = $0 }
    }

    /// M20: accepted → "Tandai Diproses" (.processed), processed →
    /// "Tandai Didaur Ulang" (.recycled). The matched rows adopt the
    /// server-returned status; an `INVALID_BOOKING_TRANSITION` means local
    /// rows drifted from the server, so both lists reload before failing.
    func advanceTracking(bookingId: UUID, status: BookingStatusCode) async -> Bool {
        guard let receptionRepository else { return false }
        do {
            let result = try await receptionRepository.advanceTracking(
                bookingId: bookingId,
                status: status
            )
            replace(status: result.status, for: result.bookingId)
            NotificationCenter.default.post(name: .adminOperationsDidChange, object: nil)
            return true
        } catch let BackendError.api(code, _, _, _) where code == "INVALID_BOOKING_TRANSITION" {
            await loadDonations()
            await loadEvents()
            return false
        } catch {
            return false
        }
    }

    // MARK: - Internals

    private func loadMore(
        _ cursor: ReferenceWritableKeyPath<AdminHistoryModel, String?>,
        fetch: (String?) async throws -> HistoryPage,
        apply: (HistoryPage) -> Void,
        setError: (String) -> Void
    ) async {
        guard let cursorValue = self[keyPath: cursor], !cursorValue.isEmpty else { return }
        do {
            let page = try await fetch(cursorValue)
            apply(page)
            self[keyPath: cursor] = page.nextCursor
        } catch let BackendError.api(code, _, _, _) where code == "CURSOR_INVALID" {
            // A stale cursor must not silently merge a shifted page: drop it
            // and rebuild from the first page.
            self[keyPath: cursor] = nil
            if cursor == \.donationCursor {
                await loadDonations()
            } else {
                await loadEvents()
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    private static func appended(_ current: [BookingHistoryItem], _ page: [BookingHistoryItem]) -> [BookingHistoryItem] {
        let known = Set(current.map(\.bookingId))
        return current + page.filter { !known.contains($0.bookingId) }
    }

    private func replace(status: BookingStatusCode, for bookingId: UUID) {
        donations = donations.map {
            $0.bookingId == bookingId ? $0.updating(status: status) : $0
        }
        events = events.map {
            $0.bookingId == bookingId ? $0.updating(status: status) : $0
        }
    }
}

private extension BookingHistoryItem {
    func updating(status: BookingStatusCode) -> BookingHistoryItem {
        BookingHistoryItem(
            bookingId: bookingId,
            publicBookingId: publicBookingId,
            status: status,
            estimatedWeightGrams: estimatedWeightGrams,
            actualWeightGrams: actualWeightGrams,
            event: event,
            createdAt: createdAt,
            statusUpdatedAt: statusUpdatedAt
        )
    }
}
