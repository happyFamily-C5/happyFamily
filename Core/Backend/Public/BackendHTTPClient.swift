import Foundation

protocol PublicBackendServing: Sendable {
    func resolveEvent(invocationToken: String) async throws -> ResolveEventData
    func createBooking(
        _ request: CreateBookingRequest,
        idempotencyKey: String
    ) async throws -> CreateBookingData
    func verifyDonor(bookingId: String, phone: String) async throws -> DonorVerificationData
    func donorBookingStatus(accessToken: String) async throws -> DonorBookingStatusData
}

struct PublicBackendClient: PublicBackendServing, Sendable {
    private let environment: BackendEnvironment
    private let session: URLSession

    init(environment: BackendEnvironment, session: URLSession = PublicBackendClient.makeSession()) {
        self.environment = environment
        self.session = session
    }

    func resolveEvent(invocationToken: String) async throws -> ResolveEventData {
        var components = URLComponents(
            url: endpoint("resolve-event"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "token", value: invocationToken)]
        guard let url = components?.url else { throw BackendError.invalidInvocationURL }
        var request = baseRequest(url: url, method: "GET")
        request.cachePolicy = .reloadRevalidatingCacheData
        return try await send(request, body: Int?.none, retryCount: 2)
    }

    func createBooking(
        _ payload: CreateBookingRequest,
        idempotencyKey: String
    ) async throws -> CreateBookingData {
        var request = baseRequest(url: endpoint("create-booking"), method: "POST")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        return try await send(request, body: payload, retryCount: 1)
    }

    func verifyDonor(bookingId: String, phone: String) async throws -> DonorVerificationData {
        let payload = DonorVerificationRequest(bookingId: bookingId, phone: phone)
        let request = baseRequest(url: endpoint("verify-donor-booking"), method: "POST")
        return try await send(request, body: payload, retryCount: 0)
    }

    func donorBookingStatus(accessToken: String) async throws -> DonorBookingStatusData {
        var request = baseRequest(url: endpoint("donor-booking-status"), method: "GET")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(request, body: Int?.none, retryCount: 1)
    }

    private func endpoint(_ name: String) -> URL {
        environment.functionsURL.appending(path: name)
    }

    private func baseRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(environment.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Request-ID")
        return request
    }

    private func send<Value: Decodable & Sendable>(
        _ request: URLRequest,
        body: (some Encodable & Sendable)?,
        retryCount: Int
    ) async throws -> Value {
        var request = request
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder().encode(body)
        }

        var remainingRetries = retryCount
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else {
                    throw BackendError.invalidResponse
                }
                return try Self.decodeResponse(data, response: response)
            } catch let error as BackendError {
                guard remainingRetries > 0, error.isRetryable else {
                    throw error
                }
                remainingRetries -= 1
                try await Task.sleep(for: .milliseconds(250))
            } catch let error as URLError {
                if error.code == .cancelled {
                    throw CancellationError()
                }
                guard remainingRetries > 0, Self.isRetryable(error) else {
                    throw BackendError.transport(error.code.rawValue.description)
                }
                remainingRetries -= 1
                try await Task.sleep(for: .milliseconds(250))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw BackendError.transport(String(describing: error))
            }
        }
    }

    private static func decodeResponse<Value: Decodable & Sendable>(
        _ data: Data,
        response: HTTPURLResponse
    ) throws -> Value {
        let envelope: BackendEnvelope<Value>
        do {
            envelope = try decoder().decode(BackendEnvelope<Value>.self, from: data)
        } catch {
            throw BackendError.decoding(String(describing: error))
        }
        if let error = envelope.error {
            throw BackendError.api(
                code: error.code,
                retryable: error.retryable,
                fieldErrors: error.fieldErrors?.values ?? [:],
                requestId: envelope.requestId
            )
        }
        guard (200 ..< 300).contains(response.statusCode), let value = envelope.data else {
            throw BackendError.invalidResponse
        }
        return value
    }

    private static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost:
            true
        default:
            false
        }
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]
            if let date = withFractional.date(from: value) ?? withoutFractional.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        return decoder
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 2 * 1024 * 1024,
            diskCapacity: 8 * 1024 * 1024
        )
        return URLSession(configuration: configuration)
    }
}

private extension BackendError {
    var isRetryable: Bool {
        if case let .api(_, retryable, _, _) = self {
            return retryable
        }
        return false
    }
}

private struct DonorVerificationRequest: Encodable, Sendable {
    let bookingId: String
    let phone: String
}
