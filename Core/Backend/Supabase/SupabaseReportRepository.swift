import Foundation
actor SupabaseReportRepository: ReportRepository {
    private let edge: any OrganizerEdgeServing

    init(edge: any OrganizerEdgeServing) {
        self.edge = edge
    }

    func recap(eventId: UUID?) async throws -> AdminRecapData {
        try await edge.recap(eventId: eventId)
    }

    func donationHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage {
        try await edge.donationHistory(eventId: eventId, cursor: cursor)
    }

    func eventHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage {
        try await edge.eventHistory(eventId: eventId, cursor: cursor)
    }
}
