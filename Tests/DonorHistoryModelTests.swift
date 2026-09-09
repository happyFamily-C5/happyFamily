import Foundation
@testable import happyFamily
import Testing

@Suite("Donor history model", .serialized)
@MainActor
struct DonorHistoryModelTests {
    @Test("loadMore appends the next page without duplicates")
    func loadMoreAppendsWithoutDuplicates() async {
        let first = item()
        let second = item()
        let repository = FakeAccountClient(
            donationPages: [
                page([first], cursor: "c1"),
                page([first, second], cursor: nil),
            ]
        )
        let model = DonorHistoryModel(accountClient: repository)

        await model.loadDonations()
        await model.loadMoreDonations()

        #expect(model.donations.map(\.bookingId) == [first.bookingId, second.bookingId])
        #expect(model.hasMoreDonations == false)
        #expect(model.donationError == nil)
        #expect(repository.donationCursors == [nil, "c1"])
    }

    @Test("eventHistory applies the terminal filter on every page")
    func completedLoadsTerminalFilter() async {
        let repository = FakeAccountClient(
            eventPages: [page([item()], cursor: nil)]
        )
        let model = DonorHistoryModel(accountClient: repository)

        await model.loadCompleted()

        #expect(model.completed.count == 1)
        #expect(repository.eventTerminals == [true])
    }

    @Test("CURSOR_INVALID on loadMore rebuilds from the first page")
    func cursorInvalidResetsToFirstPage() async {
        let first = item()
        let fresh = item()
        let repository = FakeAccountClient(
            donationPages: [
                page([first], cursor: "stale"),
                page([fresh], cursor: "c2"),
            ]
        )
        let model = DonorHistoryModel(accountClient: repository)

        await model.loadDonations()
        repository.oneShotDonationError = BackendError.api(
            code: "CURSOR_INVALID",
            retryable: false,
            fieldErrors: [:],
            requestId: nil
        )
        await model.loadMoreDonations()

        #expect(model.donations.map(\.bookingId) == [fresh.bookingId])
        #expect(model.hasMoreDonations)
        #expect(model.donationError == nil)
        #expect(repository.donationCursors == [nil, "stale", nil])
    }
}

private func item() -> BookingHistoryItem {
    BookingHistoryItem(
        bookingId: UUID(),
        publicBookingId: "KMP-\(UUID().uuidString.prefix(4))",
        status: .accepted,
        estimatedWeightGrams: 500,
        actualWeightGrams: 750,
        event: BookingEventSnapshot(
            id: UUID(),
            name: "Acara Uji",
            status: .ongoing,
            startAt: nil,
            endAt: nil,
            locationName: nil,
            bannerObjectPath: nil
        ),
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        statusUpdatedAt: nil
    )
}

private func page(_ items: [BookingHistoryItem], cursor: String?) -> HistoryPage {
    HistoryPage(items: items, nextCursor: cursor)
}

private final class FakeAccountClient: AccountBackendServing, @unchecked Sendable {
    private var donationQueue: [HistoryPage]
    private var eventQueue: [HistoryPage]
    private(set) var donationCursors: [String?] = []
    private(set) var eventTerminals: [Bool?] = []
    var oneShotDonationError: Error?

    init(donationPages: [HistoryPage] = [], eventPages: [HistoryPage] = []) {
        donationQueue = donationPages
        eventQueue = eventPages
    }

    func completeOnboarding(role _: AccountRoleCode) async throws -> AccountOnboardingData {
        throw BackendError.configuration("unused in history tests")
    }

    func myProfile() async throws -> AccountProfileData {
        throw BackendError.configuration("unused in history tests")
    }

    func updateProfile(_: AccountProfileUpdate) async throws -> AccountProfileData {
        throw BackendError.configuration("unused in history tests")
    }

    func updateWorkspace(_: AccountWorkspaceUpdate) async throws {
        throw BackendError.configuration("unused in history tests")
    }

    func requestEmailChange(email _: String) async throws -> AccountEmailChangeData {
        throw BackendError.configuration("unused in history tests")
    }

    func dashboard() async throws -> DonorDashboardData {
        throw BackendError.configuration("unused in history tests")
    }

    func eventDetail(id _: UUID) async throws -> DonorEventDetail {
        throw BackendError.configuration("unused in history tests")
    }

    func myBookings() async throws -> [DonorBookingListItem] {
        throw BackendError.configuration("unused in history tests")
    }

    func bookingDetail(id _: UUID) async throws -> DonorBookingDetail {
        throw BackendError.configuration("unused in history tests")
    }

    func donationHistory(limit: Int, cursor: String?) async throws -> HistoryPage {
        donationCursors.append(cursor)
        if let oneShotDonationError {
            self.oneShotDonationError = nil
            throw oneShotDonationError
        }
        guard !donationQueue.isEmpty else { throw BackendError.invalidResponse }
        return donationQueue.removeFirst()
    }

    func eventHistory(terminal: Bool?, limit _: Int, cursor _: String?) async throws -> HistoryPage {
        eventTerminals.append(terminal)
        guard !eventQueue.isEmpty else { throw BackendError.invalidResponse }
        return eventQueue.removeFirst()
    }

    func createBooking(
        eventId _: UUID,
        booking _: AccountBookingBody,
        idempotencyKey _: String
    ) async throws -> CreateBookingResult {
        throw BackendError.configuration("unused in history tests")
    }

    func cancelBooking(id _: UUID, idempotencyKey _: String) async throws -> CancelBookingResult {
        throw BackendError.configuration("unused in history tests")
    }
}
