import Foundation
import Observation

/// Donor histories from `account:donation_history` (bookings that reached
/// reception: accepted/processed/recycled) and `account:event_history` with
/// the terminal filter (lifecycle finished). Same wire shape as the admin
/// histories: `{ items, next_cursor }` of booking rows.
@MainActor
@Observable
final class DonorHistoryModel {
    private(set) var donations: [BookingHistoryItem] = []
    private(set) var completed: [BookingHistoryItem] = []

    private(set) var isLoadingDonations = false
    private(set) var isLoadingCompleted = false
    private(set) var isLoadingMoreDonations = false
    private(set) var isLoadingMoreCompleted = false

    var donationError: String?
    var completedError: String?

    private var donationCursor: String?
    private var completedCursor: String?

    private let accountClient: (any AccountBackendServing)?
    private let backendBaseURL: URL?

    init(
        accountClient: (any AccountBackendServing)?,
        backendBaseURL: URL? = BackendDependencies.backendBaseURL()
    ) {
        self.accountClient = accountClient
        self.backendBaseURL = backendBaseURL
    }

    var hasMoreDonations: Bool {
        donationCursor != nil
    }

    var hasMoreCompleted: Bool {
        completedCursor != nil
    }

    func loadDonations() async {
        guard let accountClient, !isLoadingDonations else { return }
        isLoadingDonations = true
        defer { isLoadingDonations = false }
        do {
            let page = try await accountClient.donationHistory(limit: 20, cursor: nil)
            donations = page.items
            donationCursor = page.nextCursor
            donationError = nil
        } catch {
            donationError = error.localizedDescription
        }
    }

    func loadMoreDonations() async {
        await loadMore(\.donationCursor) { cursor in
            guard let client = self.accountClient else {
                throw BackendError.configuration("account history is unavailable")
            }
            return try await client.donationHistory(limit: 20, cursor: cursor)
        } apply: { page in
            self.donations = Self.appended(self.donations, page.items)
            self.donationError = nil
        } setError: { self.donationError = $0 }
    }

    func loadCompleted() async {
        guard let accountClient, !isLoadingCompleted else { return }
        isLoadingCompleted = true
        defer { isLoadingCompleted = false }
        do {
            let page = try await accountClient.eventHistory(terminal: true, limit: 20, cursor: nil)
            completed = page.items
            completedCursor = page.nextCursor
            completedError = nil
        } catch {
            completedError = error.localizedDescription
        }
    }

    func loadMoreCompleted() async {
        await loadMore(\.completedCursor) { cursor in
            guard let client = self.accountClient else {
                throw BackendError.configuration("account history is unavailable")
            }
            return try await client.eventHistory(terminal: true, limit: 20, cursor: cursor)
        } apply: { page in
            self.completed = Self.appended(self.completed, page.items)
            self.completedError = nil
        } setError: { self.completedError = $0 }
    }

    // MARK: - Internals

    private func loadMore(
        _ cursor: ReferenceWritableKeyPath<DonorHistoryModel, String?>,
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
                await loadCompleted()
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    private static func appended(_ current: [BookingHistoryItem], _ page: [BookingHistoryItem]) -> [BookingHistoryItem] {
        let known = Set(current.map(\.bookingId))
        return current + page.filter { !known.contains($0.bookingId) }
    }

    /// Public banner URL for a history row's event snapshot. Cosmetic: nil
    /// on any missing piece, never fails the screen.
    func bannerURL(for item: BookingHistoryItem) -> URL? {
        guard let backendBaseURL, let path = item.event.bannerObjectPath, !path.isEmpty else {
            return nil
        }
        return backendBaseURL
            .appending(path: "storage/v1/object/public/event-banners", directoryHint: .isDirectory)
            .appending(path: path)
    }
}
