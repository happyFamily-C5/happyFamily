import Foundation

protocol OrganizerEdgeServing: Sendable {
    func listEvents(cursor: String?) async throws -> EventListResponse
    func workspaceProfile() async throws -> WorkspaceProfileData
    func uploadEventBanner(data: Data, contentType: String) async throws -> BannerUploadData
    func upsertEventDraft(eventId: UUID?, mutationId: UUID, payload: EventDraftPayload) async throws -> EventRecordDTO
    func cancelOrDeleteEvent(eventId: UUID) async throws -> CancelEventData
    func publish(eventId: UUID) async throws -> PublishEventData
    func resolveQR(token: String) async throws -> ResolvedQRBooking
    func decideReception(_ input: ReceptionDecisionInput) async throws -> ReceptionDecisionData
    func advanceTracking(bookingId: UUID, status: BookingStatusCode) async throws -> TrackingMutationData
    func recap(eventId: UUID?) async throws -> AdminRecapData
    func donationHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage
    func eventHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage
}

extension OrganizerEdgeServing {
    func listEvents(cursor _: String?) async throws -> EventListResponse {
        throw BackendError.configuration("operations list_events is unavailable")
    }

    func decideReception(_: ReceptionDecisionInput) async throws -> ReceptionDecisionData {
        throw BackendError.configuration("operations decide_reception is unavailable")
    }

    func advanceTracking(bookingId _: UUID, status _: BookingStatusCode) async throws -> TrackingMutationData {
        throw BackendError.configuration("operations advance_tracking is unavailable")
    }

    func recap(eventId _: UUID?) async throws -> AdminRecapData {
        throw BackendError.configuration("operations recap is unavailable")
    }
}

struct EventListResponse: Decodable, Sendable, Equatable {
    let items: [EventRecordDTO]
    let nextCursor: String?
}

struct WorkspaceProfileData: Decodable, Sendable, Equatable {
    let id: UUID
    let name: String
    let officeAddress: String?
    let officePhoneE164: String?
    let officeEmail: String?
    let publishable: Bool
    let logoObjectPath: String?
}

struct OrganizerBackendHTTPClient: OrganizerEdgeServing, Sendable {
    private let environment: BackendEnvironment
    private let session: URLSession
    private let accessToken: @Sendable () async throws -> String

    init(
        environment: BackendEnvironment,
        session: URLSession = OrganizerBackendHTTPClient.makeSession(),
        accessToken: @escaping @Sendable () async throws -> String
    ) {
        self.environment = environment
        self.session = session
        self.accessToken = accessToken
    }

    func uploadEventBanner(data: Data, contentType: String) async throws -> BannerUploadData {
        let boundary = "kumpul-\(UUID().uuidString.lowercased())"
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"banner\"\r\n")
        body.appendUTF8("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        var request = try await makeBaseRequest("admin-banner", method: "POST")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = body
        return try await decodeEnvelope(executeRaw(request))
    }

    func listEvents(cursor: String?) async throws -> EventListResponse {
        try await send(
            "operations",
            method: "POST",
            body: ListEventsRequest(cursor: cursor),
            idempotencyKey: nil
        )
    }

    func workspaceProfile() async throws -> WorkspaceProfileData {
        try await send("operations", method: "POST", body: WorkspaceProfileRequest(), idempotencyKey: nil)
    }

    func upsertEventDraft(
        eventId: UUID?,
        mutationId: UUID,
        payload: EventDraftPayload
    ) async throws -> EventRecordDTO {
        try await send(
            "operations",
            method: "POST",
            body: UpsertEventDraftRequest(
                eventId: eventId,
                mutationId: mutationId,
                payload: payload
            ),
            idempotencyKey: nil
        )
    }

    /// The server decides between deleting a draft and cancelling a live
    /// event. The deterministic key scopes retries to this admin + event, so
    /// a replayed cancel returns the stored decision instead of erroring.
    func cancelOrDeleteEvent(eventId: UUID) async throws -> CancelEventData {
        try await send(
            "operations",
            method: "POST",
            body: CancelOrDeleteEventRequest(eventId: eventId),
            idempotencyKey: "cancel-delete-\(eventId.uuidString)"
        )
    }

    func publish(eventId: UUID) async throws -> PublishEventData {
        try await send(
            "operations",
            method: "POST",
            body: PublishEventRequest(eventId: eventId),
            idempotencyKey: "publish-event-\(eventId.uuidString)"
        )
    }

    func resolveQR(token: String) async throws -> ResolvedQRBooking {
        try await send(
            "operations",
            method: "POST",
            body: ResolveQRRequest(qrToken: token),
            idempotencyKey: nil
        )
    }

    func decideReception(_ input: ReceptionDecisionInput) async throws -> ReceptionDecisionData {
        try await send(
            "operations", method: "POST", body: DecideReceptionRequest(input: input),
            idempotencyKey: input.idempotencyKey
        )
    }

    func advanceTracking(bookingId: UUID, status: BookingStatusCode) async throws -> TrackingMutationData {
        guard status == .processed || status == .recycled else {
            throw BackendError.configuration("Invalid admin tracking destination")
        }
        return try await send(
            "operations", method: "POST", body: AdvanceTrackingRequest(bookingId: bookingId, status: status),
            idempotencyKey: "advance-tracking-\(bookingId.uuidString)-\(status.rawValue)"
        )
    }

    func recap(eventId: UUID?) async throws -> AdminRecapData {
        try await send("operations", method: "POST", body: RecapRequest(eventId: eventId), idempotencyKey: nil)
    }

    func donationHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage {
        try await send(
            "operations", method: "POST", body: DonationHistoryRequest(eventId: eventId, cursor: cursor),
            idempotencyKey: nil
        )
    }

    func eventHistory(eventId: UUID?, cursor: String?) async throws -> HistoryPage {
        try await send(
            "operations", method: "POST", body: EventHistoryRequest(eventId: eventId, cursor: cursor),
            idempotencyKey: nil
        )
    }

    private func send<Value: Decodable & Sendable>(
        _ function: String,
        method: String,
        body: some Encodable & Sendable,
        idempotencyKey: String?
    ) async throws -> Value {
        let request = try await makeRequest(
            function,
            method: method,
            body: body,
            idempotencyKey: idempotencyKey
        )
        let data = try await executeRaw(request)
        return try decodeEnvelope(data)
    }

    private func makeRequest(
        _ function: String,
        method: String,
        body: some Encodable & Sendable,
        idempotencyKey: String?
    ) async throws -> URLRequest {
        var request = try await makeBaseRequest(function, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try BackendJSON.encoder().encode(body)
        return request
    }

    private func makeBaseRequest(_ function: String, method: String) async throws -> URLRequest {
        let token = try await accessToken()
        var request = URLRequest(url: environment.functionsURL.appending(path: function))
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(environment.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Request-ID")
        return request
    }

    private func decodeEnvelope<Value: Decodable & Sendable>(_ data: Data) throws -> Value {
        do {
            let envelope = try BackendJSON.decoder().decode(BackendEnvelope<Value>.self, from: data)
            if let error = envelope.error {
                throw BackendError.api(
                    code: error.code,
                    retryable: error.retryable,
                    fieldErrors: error.fieldErrors?.values ?? [:],
                    requestId: envelope.requestId
                )
            }
            guard let value = envelope.data else { throw BackendError.invalidResponse }
            return value
        } catch let error as BackendError {
            throw error
        } catch {
            throw BackendError.decoding(String(describing: error))
        }
    }

    private func executeRaw(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw BackendError.invalidResponse
            }
            guard (200 ..< 300).contains(response.statusCode) else {
                if let envelope = try? BackendJSON.decoder().decode(
                    BackendEnvelope<EmptyData>.self,
                    from: data
                ), let error = envelope.error {
                    throw BackendError.api(
                        code: error.code,
                        retryable: error.retryable,
                        fieldErrors: error.fieldErrors?.values ?? [:],
                        requestId: envelope.requestId
                    )
                }
                throw BackendError.invalidResponse
            }
            return data
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as BackendError {
            throw error
        } catch let error as URLError {
            throw BackendError.transport(String(error.code.rawValue))
        } catch {
            throw BackendError.transport(String(describing: error))
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}

private struct PublishEventRequest: Encodable, Sendable {
    let action = "publish_event"
    let eventId: UUID
}

private struct ListEventsRequest: Encodable, Sendable {
    let action = "list_events"
    let limit = 100
    let cursor: String?
}

private struct WorkspaceProfileRequest: Encodable, Sendable {
    let action = "workspace_profile"
}

private struct UpsertEventDraftRequest: Encodable, Sendable {
    let action = "upsert_event_draft"
    let eventId: UUID?
    let mutationId: UUID
    let payload: EventDraftPayload
}

private struct CancelOrDeleteEventRequest: Encodable, Sendable {
    let action = "cancel_or_delete_event"
    let eventId: UUID
}

private struct ResolveQRRequest: Encodable, Sendable {
    let action = "resolve_qr"
    let qrToken: String
}

private struct DecideReceptionRequest: Encodable, Sendable {
    let action = "decide_reception"
    let bookingId: UUID
    let decision: ReceptionDecisionCode
    let actualWeightGrams: Int64?

    init(input: ReceptionDecisionInput) {
        bookingId = input.bookingId
        decision = input.decision
        actualWeightGrams = input.decision == .accepted ? input.actualWeightGrams : nil
    }
}

private struct AdvanceTrackingRequest: Encodable, Sendable {
    let action = "advance_tracking"
    let bookingId: UUID
    let status: BookingStatusCode
}

private struct RecapRequest: Encodable, Sendable {
    let action = "recap"
    let eventId: UUID?
    let days = 31
}

private struct DonationHistoryRequest: Encodable, Sendable {
    let action = "donation_history"
    let eventId: UUID?
    let limit = 20
    let cursor: String?
}

private struct EventHistoryRequest: Encodable, Sendable {
    let action = "event_history"
    let eventId: UUID?
    let limit = 20
    let cursor: String?
}

private struct EmptyData: Decodable, Sendable {}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(contentsOf: value.utf8)
    }
}
