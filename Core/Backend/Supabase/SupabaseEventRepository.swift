import Foundation
import Supabase

actor SupabaseEventRepository: EventRepository {
    private let client: SupabaseClient
    private let edge: any OrganizerEdgeServing

    init(client: SupabaseClient, edge: any OrganizerEdgeServing) {
        self.client = client
        self.edge = edge
    }

    func publish(eventId: UUID) async throws -> PublishEventData {
        try await edge.publish(eventId: eventId)
    }

    func list(cursor: String?) async throws -> EventPage {
        let response = try await client
            .schema("api")
            .rpc(
                "list_events_v2",
                params: ListEventsParameters(
                    cursor: cursor,
                    limit: 100
                )
            )
            .execute()
        let page = try BackendJSON.decoder().decode(EventListResponse.self, from: response.data)
        return EventPage(events: page.items.map { BackendAdminEvent(record: $0) }, cursor: page.cursor)
    }

    func upsertDraft(_ event: BackendAdminEvent, mutationId: UUID) async throws -> BackendAdminEvent {
        var preparedEvent = event
        if let bannerData = event.bannerImageData {
            let contentType = bannerData.starts(with: [0x89, 0x50, 0x4E, 0x47])
                ? "image/png"
                : "image/jpeg"
            let uploaded = try await edge.uploadEventBanner(
                data: bannerData,
                contentType: contentType
            )
            preparedEvent.bannerObjectPath = uploaded.objectPath
        }
        let record = try await edge.upsertEventDraft(
            eventId: preparedEvent.id,
            mutationId: mutationId,
            payload: EventDraftPayload(event: preparedEvent)
        )
        return BackendAdminEvent(record: record, bannerImageData: event.bannerImageData)
    }

    func cancelOrDelete(eventId: UUID) async throws -> CancelEventData {
        try await edge.cancelOrDeleteEvent(eventId: eventId)
    }
}

private struct EventListResponse: Decodable {
    let items: [EventRecordDTO]
    let cursor: String?
}


private extension BackendAdminEvent {
    init(record: EventRecordDTO, bannerImageData: Data? = nil) {
        self.init(
            id: record.id,
            name: record.name ?? "Draf tanpa nama",
            description: record.description,
            startDate: record.startAt ?? .distantFuture,
            endDate: record.endAt ?? .distantFuture,
            capacityKg: Int((record.capacityGrams ?? 0) / 1000),
            collectedKg: Double(record.receivedWeightGrams) / 1000,
            bannerImageData: bannerImageData,
            bannerObjectPath: record.bannerObjectPath,
            status: record.status,
            timezoneName: record.timezoneName ?? "Asia/Jakarta",
            operationalDays: record.operationalDays ?? [],
            opensAtLocal: record.opensAtLocal ?? "08:00:00",
            closesAtLocal: record.closesAtLocal ?? "17:00:00",
            locationName: record.locationName,
            locationAddress: record.locationAddress,
            latitude: record.latitude,
            longitude: record.longitude,
            criteria: record.criteria,
            maxDonationPerUserKg: record.maxDonationPerUserGrams.map { Int($0 / 1000) },
            receiverName: record.receiverName,
            receiverPhone: record.receiverPhone,
            receiverAddress: record.receiverAddress,
            version: record.version ?? 0
        )
    }
}

private struct ListEventsParameters: Encodable {
    let cursor: String?
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case cursor = "p_cursor"
        case limit = "p_limit"
    }
}


