import Foundation
import Supabase

actor SupabaseReportRepository: ReportRepository {
    private let client: SupabaseClient
    private let edge: any OrganizerEdgeServing

    init(client: SupabaseClient, edge: any OrganizerEdgeServing) {
        self.client = client
        self.edge = edge
    }

    func recap(eventId: UUID?) async throws -> RecapData {
        let response = try await client
            .schema("api")
            .rpc("recap_v1", params: RecapParameters(eventId: eventId))
            .execute()
        return try BackendJSON.decoder().decode(RecapData.self, from: response.data)
    }

    func exportCSV(filter: ReportFilter) async throws -> Data {
        try await edge.exportCSV(filter: filter)
    }

    func deleteDonorData(bookingId: UUID) async throws {
        try await edge.deleteDonorData(bookingId: bookingId)
    }
}

private struct RecapParameters: Encodable, Sendable {
    let eventId: UUID?

    enum CodingKeys: String, CodingKey {
        case eventId = "p_event_id"
    }
}
