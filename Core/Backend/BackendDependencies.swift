import Foundation
import Supabase

enum BackendDependencies {
    private static let eventStore = try? SwiftDataEventStore.make()

    /// One Supabase client per process. Auth sessions live in each client's
    /// in-memory auth actor, so a sign-in through one instance is invisible
    /// to repositories built on another — every factory must share this one.
    private static let sharedClient: SupabaseClient? = {
        guard let environment = try? BackendEnvironment.load(bundle: .main) else {
            return nil
        }
        return SupabaseClient(
            supabaseURL: environment.baseURL,
            supabaseKey: environment.publishableKey
        )
    }()

    static func makeClient(environment: BackendEnvironment) -> SupabaseClient {
        if let sharedClient {
            return sharedClient
        }
        return SupabaseClient(
            supabaseURL: environment.baseURL,
            supabaseKey: environment.publishableKey
        )
    }

    static func eventRepository(bundle: Bundle = .main) -> any EventRepository {
        do {
            let environment = try BackendEnvironment.load(bundle: bundle)
            let client = makeClient(environment: environment)
            let remote = SupabaseEventRepository(
                client: client,
                edge: makeOrganizerEdge(environment: environment, client: client)
            )
            guard let eventStore else { return remote }
            return CachedEventRepository(remote: remote, store: eventStore) {
                try await client.auth.session.user.id
            }
        } catch let error as BackendError {
            return UnavailableEventRepository(error: error)
        } catch {
            return UnavailableEventRepository(error: .configuration("unknown"))
        }
    }

    static func authSession(bundle: Bundle = .main) throws -> any AuthSession {
        let environment = try BackendEnvironment.load(bundle: bundle)
        return SupabaseAuthSession(client: makeClient(environment: environment))
    }

    static func logoutService(bundle: Bundle = .main) throws -> LogoutService {
        try LogoutService(
            auth: authSession(bundle: bundle),
            cache: eventStore ?? EmptySessionCache()
        )
    }

    /// Non-throwing variant for view-layer default arguments: returns nil
    /// instead of throwing when backend configuration is incomplete.
    static func authSessionOrDefault(bundle: Bundle = .main) -> (any AuthSession)? {
        try? authSession(bundle: bundle)
    }

    static func receptionRepository(bundle: Bundle = .main) throws -> any ReceptionRepository {
        let environment = try BackendEnvironment.load(bundle: bundle)
        let client = makeClient(environment: environment)
        return SupabaseReceptionRepository(
            client: client,
            edge: makeOrganizerEdge(environment: environment, client: client)
        )
    }

    static func reportRepository(bundle: Bundle = .main) throws -> any ReportRepository {
        let environment = try BackendEnvironment.load(bundle: bundle)
        let client = makeClient(environment: environment)
        return SupabaseReportRepository(
            client: client,
            edge: makeOrganizerEdge(environment: environment, client: client)
        )
    }

    /// Non-throwing variant for view-layer default arguments: returns nil
    /// instead of crashing when backend configuration is incomplete.
    static func reportRepositoryOrDefault(bundle: Bundle = .main) -> (any ReportRepository)? {
        try? reportRepository(bundle: bundle)
    }

    private static func makeOrganizerEdge(
        environment: BackendEnvironment,
        client: SupabaseClient
    ) -> OrganizerBackendHTTPClient {
        OrganizerBackendHTTPClient(environment: environment) {
            let session = try await client.auth.session
            return session.accessToken
        }
    }
}

private struct EmptySessionCache: SessionCache {
    func purge() async {}
}

private struct UnavailableEventRepository: EventRepository {
    let error: BackendError

    func list(cursor _: String?) async throws -> EventPage {
        throw error
    }

    func upsertDraft(_: AdminEvent, mutationId _: UUID) async throws -> AdminEvent {
        throw error
    }

    func publish(eventId _: UUID) async throws -> PublishEventData {
        throw error
    }

    func terminate(
        eventId _: UUID,
        status _: EventStatusCode,
        reason _: String?
    ) async throws -> AdminEvent {
        throw error
    }
}
