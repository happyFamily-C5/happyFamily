import Foundation
import Supabase

actor SupabaseReceptionRepository: ReceptionRepository {
    private let client: SupabaseClient
    private let edge: any OrganizerEdgeServing

    init(client: SupabaseClient, edge: any OrganizerEdgeServing) {
        self.client = client
        self.edge = edge
    }

    func resolveQR(token: String) async throws -> ResolvedQRBooking {
        try await edge.resolveQR(token: token)
    }

    func decide(_ input: ReceptionDecisionInput) async throws -> ReceptionDecisionData {
        let response = try await client
            .schema("api")
            .rpc("decide_reception_v1", params: ReceptionDecisionParameters(input: input))
            .execute()
        return try BackendJSON.decoder().decode(ReceptionDecisionData.self, from: response.data)
    }
}

private struct ReceptionDecisionParameters: Encodable, Sendable {
    let bookingId: UUID
    let decision: ReceptionDecisionCode
    let actualWeightGrams: Int64
    let condition: ReceptionConditionCode
    let rejectionReason: RejectionReasonCode?
    let rejectionNote: String?
    let idempotencyKey: String
    let requestId: UUID

    init(input: ReceptionDecisionInput) {
        bookingId = input.bookingId
        decision = input.decision
        actualWeightGrams = input.actualWeightGrams
        condition = input.condition
        rejectionReason = input.rejectionReason
        rejectionNote = input.rejectionNote
        idempotencyKey = input.idempotencyKey
        requestId = input.requestId
    }

    enum CodingKeys: String, CodingKey {
        case bookingId = "p_booking_id"
        case decision = "p_decision"
        case actualWeightGrams = "p_actual_weight_grams"
        case condition = "p_condition"
        case rejectionReason = "p_rejection_reason"
        case rejectionNote = "p_rejection_note"
        case idempotencyKey = "p_idempotency_key"
        case requestId = "p_request_id"
    }
}
