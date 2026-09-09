import Foundation

protocol OrganizerEdgeServing: Sendable {
    func uploadEventBanner(data: Data, contentType: String) async throws -> BannerUploadData
    func upsertEventDraft(eventId: UUID?, mutationId: UUID, payload: EventDraftPayload) async throws -> EventRecordDTO
    func cancelOrDeleteEvent(eventId: UUID) async throws -> CancelEventData
    func publish(eventId: UUID) async throws -> PublishEventData
    func resolveQR(token: String) async throws -> ResolvedQRBooking
    func exportCSV(filter: ReportFilter) async throws -> Data
    func deleteDonorData(bookingId: UUID) async throws
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
            "publish-event",
            method: "POST",
            body: PublishRequest(eventId: eventId),
            idempotencyKey: nil
        )
    }

    func resolveQR(token: String) async throws -> ResolvedQRBooking {
        try await send(
            "resolve-qr",
            method: "POST",
            body: ResolveQRRequest(qrToken: token),
            idempotencyKey: nil
        )
    }

    func exportCSV(filter: ReportFilter) async throws -> Data {
        let request = try await makeRequest(
            "export-report",
            method: "POST",
            body: ExportReportRequest(filter: filter),
            idempotencyKey: nil
        )
        return try await executeRaw(request)
    }

    func deleteDonorData(bookingId: UUID) async throws {
        let _: DeletedData = try await send(
            "delete-donor-data",
            method: "DELETE",
            body: DeleteDonorDataRequest(bookingId: bookingId),
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

private struct PublishRequest: Encodable, Sendable {
    let eventId: UUID
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
    let qrToken: String
}

private struct ExportReportRequest: Encodable, Sendable {
    let eventId: UUID?
    let createdFrom: Date?
    let createdTo: Date?

    init(filter: ReportFilter) {
        eventId = filter.eventId
        createdFrom = filter.createdFrom
        createdTo = filter.createdTo
    }
}

private struct DeleteDonorDataRequest: Encodable, Sendable {
    let bookingId: UUID
}

private struct DeletedData: Decodable, Sendable {
    let deleted: Bool
}

private struct EmptyData: Decodable, Sendable {}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(contentsOf: value.utf8)
    }
}
