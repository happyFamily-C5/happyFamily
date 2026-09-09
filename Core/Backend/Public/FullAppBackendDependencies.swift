import Foundation

enum FullAppBackendDependencies {
    static func client(bundle: Bundle = .main) -> any PublicBackendServing {
        do {
            return PublicBackendClient(environment: try BackendEnvironment.load(bundle: bundle))
        } catch let error as BackendError {
            return UnavailableFullAppBackendClient(error: error)
        } catch {
            return UnavailableFullAppBackendClient(error: .configuration("unknown"))
        }
    }

    static func baseURL(bundle: Bundle = .main) -> URL? {
        try? BackendEnvironment.load(bundle: bundle).baseURL
    }
}

private struct UnavailableFullAppBackendClient: PublicBackendServing {
    let error: BackendError

    func resolveEvent(invocationToken _: String) async throws -> ResolveEventData { throw error }
    func createBooking(_: CreateBookingRequest, idempotencyKey _: String) async throws -> CreateBookingData { throw error }
    func verifyDonor(bookingId _: String, phone _: String) async throws -> DonorVerificationData { throw error }
    func donorBookingStatus(accessToken _: String) async throws -> DonorBookingStatusData { throw error }
}
