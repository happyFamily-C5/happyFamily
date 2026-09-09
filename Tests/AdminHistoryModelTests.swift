import Foundation
@testable import happyFamily
import Testing

@Suite("Admin history model", .serialized)
@MainActor
struct AdminHistoryModelTests {
    @Test("loadMore appends the next page without duplicates")
    func loadMoreAppendsWithoutDuplicates() async {
        let first = item()
        let second = item()
        let repository = FakeReportRepository(
            donationPages: [
                page([first], cursor: "c1"),
                page([first, second], cursor: nil),
            ]
        )
        let model = AdminHistoryModel(historyRepository: repository, receptionRepository: nil)

        await model.loadDonations()
        await model.loadMoreDonations()

        #expect(model.donations.map(\.bookingId) == [first.bookingId, second.bookingId])
        #expect(model.hasMoreDonations == false)
        #expect(model.donationError == nil)
        #expect(repository.donationCursors == [nil, "c1"])
    }

    @Test("advanceTracking moves an accepted booking to processed in both lists")
    func advanceTrackingUpdatesRow() async {
        let bookingId = UUID()
        let repository = FakeReportRepository(
            donationPages: [page([item(id: bookingId, status: .accepted)], cursor: nil)],
            eventPages: [page([item(id: bookingId, status: .accepted)], cursor: nil)]
        )
        let reception = FakeReceptionRepository()
        reception.decisionStatus = .processed
        let model = AdminHistoryModel(historyRepository: repository, receptionRepository: reception)

        await model.loadDonations()
        await model.loadEvents()
        let advanced = await model.advanceTracking(bookingId: bookingId, status: .processed)

        #expect(advanced)
        #expect(model.donations.first?.status == .processed)
        #expect(model.events.first?.status == .processed)
        #expect(reception.advances.count == 1)
        #expect(reception.advances.first?.status == .processed)
    }

    @Test("INVALID_BOOKING_TRANSITION reloads server truth and reports failure")
    func invalidTransitionReloads() async {
        let bookingId = UUID()
        let repository = FakeReportRepository(
            donationPages: [
                page([item(id: bookingId, status: .accepted)], cursor: nil),
                page([item(id: bookingId, status: .waiting)], cursor: nil),
            ],
            eventPages: [
                page([item(id: bookingId, status: .accepted)], cursor: nil),
                page([], cursor: nil),
            ]
        )
        let reception = FakeReceptionRepository()
        reception.advanceError = BackendError.api(
            code: "INVALID_BOOKING_TRANSITION",
            retryable: false,
            fieldErrors: [:],
            requestId: nil
        )
        let model = AdminHistoryModel(historyRepository: repository, receptionRepository: reception)

        await model.loadDonations()
        let advanced = await model.advanceTracking(bookingId: bookingId, status: .processed)

        #expect(!advanced)
        #expect(model.donations.first?.status == .waiting)
    }

    @Test("CURSOR_INVALID on loadMore rebuilds from the first page")
    func cursorInvalidResetsToFirstPage() async {
        let first = item()
        let fresh = item()
        let repository = FakeReportRepository(
            donationPages: [
                page([first], cursor: "stale"),
                page([fresh], cursor: "c2"),
            ]
        )
        let model = AdminHistoryModel(historyRepository: repository, receptionRepository: nil)

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

private func item(
    id: UUID = UUID(),
    status: BookingStatusCode = .accepted,
    name: String = "Acara Uji"
) -> BookingHistoryItem {
    BookingHistoryItem(
        bookingId: id,
        publicBookingId: "KMP-\(id.uuidString.prefix(4))",
        status: status,
        estimatedWeightGrams: 500,
        actualWeightGrams: 750,
        event: BookingEventSnapshot(
            id: UUID(),
            name: name,
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

private final class FakeReportRepository: ReportRepository, @unchecked Sendable {
    private var donationQueue: [HistoryPage]
    private var eventQueue: [HistoryPage]
    private(set) var donationCursors: [String?] = []
    private(set) var eventCursors: [String?] = []
    var oneShotDonationError: Error?

    init(donationPages: [HistoryPage] = [], eventPages: [HistoryPage] = []) {
        donationQueue = donationPages
        eventQueue = eventPages
    }

    func recap(eventId _: UUID?) async throws -> AdminRecapData {
        throw BackendError.configuration("recap unused in history tests")
    }

    func donationHistory(eventId _: UUID?, cursor: String?) async throws -> HistoryPage {
        donationCursors.append(cursor)
        if let oneShotDonationError {
            self.oneShotDonationError = nil
            throw oneShotDonationError
        }
        guard !donationQueue.isEmpty else { throw BackendError.invalidResponse }
        return donationQueue.removeFirst()
    }

    func eventHistory(eventId _: UUID?, cursor: String?) async throws -> HistoryPage {
        eventCursors.append(cursor)
        guard !eventQueue.isEmpty else { throw BackendError.invalidResponse }
        return eventQueue.removeFirst()
    }
}

private final class FakeReceptionRepository: ReceptionRepository, @unchecked Sendable {
    var advanceError: Error?
    var decisionStatus: BookingStatusCode = .processed
    private(set) var advances: [(bookingId: UUID, status: BookingStatusCode)] = []

    func resolveQR(token _: String) async throws -> ResolvedQRBooking {
        throw BackendError.configuration("unused in history tests")
    }

    func decide(_: ReceptionDecisionInput) async throws -> ReceptionDecisionData {
        throw BackendError.configuration("unused in history tests")
    }

    func advanceTracking(bookingId: UUID, status: BookingStatusCode) async throws -> ReceptionDecisionData {
        advances.append((bookingId, status))
        if let advanceError { throw advanceError }
        return ReceptionDecisionData(
            bookingId: bookingId,
            publicBookingId: "KMP-TEST-001",
            status: decisionStatus,
            receivedWeightGrams: 750,
            capacityGrams: 10_000,
            capacityFull: false
        )
    }
}
