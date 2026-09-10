import Foundation
import Observation

@MainActor
@Observable
final class FullAppInvocationModel {
    private(set) var event: PublicEventDTO?
    private(set) var isLoading = false
    var errorMessage: String?

    private let injectedClient: (any PublicBackendServing)?

    init(client: (any PublicBackendServing)? = nil) {
        injectedClient = client
    }

    func handle(_ url: URL, bundle: Bundle = .main) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let invocation = try InvocationParser.parse(url)
            let client: any PublicBackendServing = if let injectedClient {
                injectedClient
            } else {
                try PublicBackendClient(environment: BackendEnvironment.load(bundle: bundle))
            }
            event = try await client.resolveEvent(invocationToken: invocation.token).event
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            event = nil
            errorMessage = error.localizedDescription
        }
    }

    func dismiss() {
        event = nil
    }
}
