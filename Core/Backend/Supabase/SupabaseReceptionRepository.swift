import Foundation
actor SupabaseReceptionRepository: ReceptionRepository {
    private let edge: any OrganizerEdgeServing

    init(edge: any OrganizerEdgeServing) {
        self.edge = edge
    }

    func resolveQR(token: String) async throws -> ResolvedQRBooking {
        try await edge.resolveQR(token: token)
    }

    func decide(_ input: ReceptionDecisionInput) async throws -> ReceptionDecisionData {
        try await edge.decideReception(input)
    }

    func advanceTracking(bookingId: UUID, status: BookingStatusCode) async throws -> ReceptionDecisionData {
        try await edge.advanceTracking(bookingId: bookingId, status: status)
    }
}
