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
        return EventPage(events: page.items.map { AdminEvent(record: $0) }, cursor: page.cursor)
    }

    func upsertDraft(_ event: AdminEvent, mutationId: UUID) async throws -> AdminEvent {
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
        let response = try await client
            .schema("api")
            .rpc(
                "upsert_event_draft_v1",
                params: UpsertEventParameters(
                    eventId: preparedEvent.id,
                    mutationId: mutationId,
                    payload: EventDraftPayload(event: preparedEvent)
                )
            )
            .execute()
        let record = try BackendJSON.decoder().decode(EventRecord.self, from: response.data)
        return AdminEvent(record: record, bannerImageData: event.bannerImageData)
    }

    func terminate(
        eventId: UUID,
        status: EventStatusCode,
        reason: String?
    ) async throws -> AdminEvent {
        guard status == .closed || status == .cancelled else {
            throw BackendError.api(
                code: "INVALID_EVENT_TRANSITION",
                retryable: false,
                fieldErrors: [:],
                requestId: nil
            )
        }
        let response = try await client
            .schema("api")
            .rpc(
                "terminate_event_v1",
                params: TerminateEventParameters(
                    eventId: eventId,
                    status: status,
                    reason: reason,
                    requestId: UUID()
                )
            )
            .execute()
        let record = try BackendJSON.decoder().decode(EventRecord.self, from: response.data)
        return AdminEvent(record: record)
    }
}

private struct EventListResponse: Decodable {
    let items: [EventRecord]
    let cursor: String?
}

private struct EventRecord: Decodable {
    let id: UUID
    let name: String?
    let description: String?
    let status: EventStatusCode
    let startAt: Date?
    let endAt: Date?
    let timezoneName: String?
    let operationalDays: [Int]?
    let opensAtLocal: String?
    let closesAtLocal: String?
    let locationName: String?
    let locationAddress: String?
    let latitude: Double?
    let longitude: Double?
    let capacityGrams: Int64?
    let receivedWeightGrams: Int64
    let bannerObjectPath: String?
    let receiverName: String?
    let receiverPhone: String?
    let receiverAddress: String?
    let criteria: [EventCriterionCode]
    let version: Int64
}

private extension AdminEvent {
    init(record: EventRecord, bannerImageData: Data? = nil) {
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
            receiverName: record.receiverName,
            receiverPhone: record.receiverPhone,
            receiverAddress: record.receiverAddress,
            version: record.version
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

private struct UpsertEventParameters: Encodable {
    let eventId: UUID?
    let mutationId: UUID
    let payload: EventDraftPayload

    enum CodingKeys: String, CodingKey {
        case eventId = "p_event_id"
        case mutationId = "p_mutation_id"
        case payload = "p_payload"
    }
}

private struct TerminateEventParameters: Encodable {
    let eventId: UUID
    let status: EventStatusCode
    let reason: String?
    let requestId: UUID

    enum CodingKeys: String, CodingKey {
        case eventId = "p_event_id"
        case status = "p_status"
        case reason = "p_reason"
        case requestId = "p_request_id"
    }
}

private struct EventDraftPayload: Encodable {
    let name: String
    let description: String?
    let startAt: String
    let endAt: String
    let timezoneName: String
    let operationalDays: [Int]
    let opensAtLocal: String
    let closesAtLocal: String
    let locationName: String?
    let locationAddress: String?
    let locationCountryCode: String
    let latitude: Double?
    let longitude: Double?
    let capacityGrams: Int64
    let bannerObjectPath: String?
    let receiverName: String?
    let receiverPhone: String?
    let receiverAddress: String?
    let criteria: [EventCriterionCode]

    init(event: AdminEvent) {
        name = event.name
        description = event.description
        startAt = event.startDate.ISO8601Format()
        endAt = event.endDate.ISO8601Format()
        timezoneName = event.timezoneName
        operationalDays = event.operationalDays
        opensAtLocal = event.opensAtLocal
        closesAtLocal = event.closesAtLocal
        locationName = event.locationName
        locationAddress = event.locationAddress
        locationCountryCode = "ID"
        latitude = event.latitude
        longitude = event.longitude
        capacityGrams = Int64(event.capacityKg) * 1000
        bannerObjectPath = event.bannerObjectPath
        receiverName = event.receiverName
        receiverPhone = event.receiverPhone
        receiverAddress = event.receiverAddress
        criteria = event.criteria
    }
}
