import Foundation
@testable import happyFamily
import Testing

@Suite("Backend contracts")
struct BackendContractTests {
    @Test("Invocation parser accepts every supported query name", arguments: [
        "event", "invocation", "token",
    ])
    func invocationParserAcceptsSupportedQueryName(_ name: String) throws {
        let token = String(repeating: "a", count: 43)
        let url = try #require(URL(string: "https://example.invalid/invoke?\(name)=\(token)"))
        #expect(try InvocationParser.parse(url) == EventInvocation(token: token))
    }

    @Test func invocationParserRejectsShortTokens() throws {
        let url = try #require(URL(string: "https://example.invalid/invoke?event=short"))
        #expect(throws: BackendError.invalidInvocationURL) {
            try InvocationParser.parse(url)
        }
    }

    @Test func environmentLoadsStagingValues() throws {
        let environment = try BackendEnvironment.load(values: [
            "KumpulBackendURL": "https://staging.example.invalid",
            "KumpulBackendPublishableKey": "publishable-test-key",
            "KumpulBackendEnvironment": "staging",
        ])
        #expect(environment.deployment == .staging)
        #expect(environment.functionsURL.absoluteString == "https://staging.example.invalid/functions/v1/")
    }

    @Test func environmentRejectsInsecureRemoteURL() {
        #expect(throws: BackendError.configuration("KumpulBackendURL")) {
            try BackendEnvironment.load(values: [
                "KumpulBackendURL": "http://staging.example.invalid",
                "KumpulBackendPublishableKey": "publishable-test-key",
                "KumpulBackendEnvironment": "staging",
            ])
        }
    }

    @Test func decoderMapsURLAcronymsFromServerKeys() throws {
        let data = Data("""
        {
          "terms_version": "terms-v1",
          "terms_url": "https://example.invalid/terms",
          "privacy_version": "privacy-v1",
          "privacy_url": "https://example.invalid/privacy"
        }
        """.utf8)
        let legal = try BackendJSON.decoder().decode(PublicLegalDTO.self, from: data)
        #expect(legal.termsURL.absoluteString == "https://example.invalid/terms")
        #expect(legal.privacyURL.absoluteString == "https://example.invalid/privacy")
    }

    @Test @MainActor func fullAppInvocationResolvesSharedURLContract() async throws {
        let event = PublicEventDTO.fixture()
        let model = FullAppInvocationModel(client: PublicBackendStub(event: event))
        let token = String(repeating: "a", count: 43)
        let url = try #require(URL(string: "https://example.invalid/invoke?event=\(token)"))

        await model.handle(url)

        #expect(model.event == event)
        #expect(model.errorMessage == nil)
    }
}

@Suite("Dashboard repository seam")
struct DashboardRepositoryTests {
    @Test @MainActor func dashboardLoadsAndCreatesThroughRepository() async {
        let existing = AdminEvent.fixture(name: "Existing", version: 1)
        let created = AdminEvent.fixture(name: "Created", version: 1)
        let repository = MockEventRepository(initial: [existing], saved: created)
        let model = DashboardModel(repository: repository)

        await model.load()
        #expect(model.events == [existing])
        await model.createDraft(AdminEvent.fixture(name: "Draft"))
        #expect(model.events == [existing, created])
        #expect(model.errorMessage == nil)
    }

    @Test func logoutPurgesSessionCacheAfterGlobalSignOut() async throws {
        let auth = AuthSessionSpy()
        let cache = SessionCacheSpy()
        try await LogoutService(auth: auth, cache: cache).logout()
        #expect(await auth.signedOut())
        #expect(await cache.wasPurged())
    }
}

@Suite("Offline draft synchronization")
struct OfflineDraftSynchronizationTests {
    @Test func latestOfflineDraftRetriesWithItsOriginalMutationId() async throws {
        let ownerUserId = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
        let firstMutationId = try #require(UUID(uuidString: "20000000-0000-4000-8000-000000000001"))
        let latestMutationId = try #require(UUID(uuidString: "20000000-0000-4000-8000-000000000002"))
        let store = try SwiftDataEventStore.make(isStoredInMemoryOnly: true)
        let remote = DraftSyncRemote()
        let repository = CachedEventRepository(remote: remote, store: store) { ownerUserId }

        let initial = AdminEvent.fixture(name: "Draf offline")
        let firstResult = try await repository.upsertDraft(initial, mutationId: firstMutationId)
        #expect(firstResult == initial)

        var latest = initial
        latest.name = "Draf offline terbaru"
        let latestResult = try await repository.upsertDraft(latest, mutationId: latestMutationId)
        #expect(latestResult == latest)

        var saved = latest
        saved.version = 1
        await remote.goOnline(savedEvent: saved)

        let page = try await repository.list(cursor: nil)
        let mutationIds = await remote.savedMutationIds()
        let pending = try await store.pendingDrafts(ownerUserId: ownerUserId)

        #expect(page.events == [saved])
        #expect(page.cursor == "server-cursor")
        #expect(mutationIds == [firstMutationId, latestMutationId, latestMutationId])
        #expect(pending.isEmpty)
    }

    @Test func cacheIsTenantScopedAndPurgedOnLogout() async throws {
        let ownerA = try #require(UUID(uuidString: "10000000-0000-4000-8000-00000000000a"))
        let ownerB = try #require(UUID(uuidString: "10000000-0000-4000-8000-00000000000b"))
        let store = try SwiftDataEventStore.make(isStoredInMemoryOnly: true)
        let eventA = AdminEvent.fixture(name: "Tenant A")
        let eventB = AdminEvent.fixture(name: "Tenant B")

        try await store.cacheRemoteEvents([eventA], cursor: "cursor-a", ownerUserId: ownerA)
        try await store.cacheRemoteEvents([eventB], cursor: "cursor-b", ownerUserId: ownerB)

        #expect(try await store.cachedEvents(ownerUserId: ownerA) == [eventA])
        #expect(try await store.cachedEvents(ownerUserId: ownerB) == [eventB])
        #expect(try await store.cursor(ownerUserId: ownerA) == "cursor-a")
        #expect(try await store.cursor(ownerUserId: ownerB) == "cursor-b")

        await store.purge()
        #expect(try await store.cachedEvents(ownerUserId: ownerA).isEmpty)
        #expect(try await store.cachedEvents(ownerUserId: ownerB).isEmpty)
    }

    @Test func publishFailureNeverEntersOfflineDraftQueue() async throws {
        let ownerUserId = try #require(UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
        let eventId = try #require(UUID(uuidString: "30000000-0000-4000-8000-000000000001"))
        let store = try SwiftDataEventStore.make(isStoredInMemoryOnly: true)
        let remote = DraftSyncRemote()
        let repository = CachedEventRepository(remote: remote, store: store) { ownerUserId }

        do {
            _ = try await repository.publish(eventId: eventId)
            Issue.record("Publish unexpectedly succeeded while offline")
        } catch is URLError {
            // Expected: publish is intentionally online-only.
        }

        let pending = try await store.pendingDrafts(ownerUserId: ownerUserId)
        #expect(pending.isEmpty)
    }
}

private enum TestFailure: Error {
    case unexpectedCall
}

private actor MockEventRepository: EventRepository {
    private let initial: [AdminEvent]
    private let saved: AdminEvent

    init(initial: [AdminEvent], saved: AdminEvent) {
        self.initial = initial
        self.saved = saved
    }

    func list(cursor _: String?) async throws -> EventPage {
        EventPage(events: initial, cursor: "opaque-cursor")
    }

    func upsertDraft(_: AdminEvent, mutationId _: UUID) async throws -> AdminEvent {
        saved
    }

    func publish(eventId _: UUID) async throws -> PublishEventData {
        throw TestFailure.unexpectedCall
    }

    func terminate(
        eventId _: UUID,
        status _: EventStatusCode,
        reason _: String?
    ) async throws -> AdminEvent {
        throw TestFailure.unexpectedCall
    }
}

private actor DraftSyncRemote: EventRepository {
    private var online = false
    private var savedEvent: AdminEvent?
    private var mutationIds: [UUID] = []

    func goOnline(savedEvent: AdminEvent) {
        online = true
        self.savedEvent = savedEvent
    }

    func savedMutationIds() -> [UUID] {
        mutationIds
    }

    func list(cursor _: String?) async throws -> EventPage {
        guard online else { throw URLError(.notConnectedToInternet) }
        return EventPage(events: [], cursor: "server-cursor")
    }

    func upsertDraft(_ event: AdminEvent, mutationId: UUID) async throws -> AdminEvent {
        mutationIds.append(mutationId)
        guard online else { throw URLError(.notConnectedToInternet) }
        return savedEvent ?? event
    }

    func publish(eventId _: UUID) async throws -> PublishEventData {
        throw URLError(.notConnectedToInternet)
    }

    func terminate(
        eventId _: UUID,
        status _: EventStatusCode,
        reason _: String?
    ) async throws -> AdminEvent {
        throw URLError(.notConnectedToInternet)
    }
}

private actor AuthSessionSpy: AuthSession {
    private var didSignOut = false

    func current() async throws -> AuthUserSession {
        throw TestFailure.unexpectedCall
    }

    func signUp(email _: String, password _: String) async throws {
        throw TestFailure.unexpectedCall
    }

    func signIn(email _: String, password _: String) async throws -> AuthUserSession {
        throw TestFailure.unexpectedCall
    }

    func signInWithApple(idToken _: String, nonce _: String) async throws -> AuthUserSession {
        throw TestFailure.unexpectedCall
    }

    func signOut() async throws {
        didSignOut = true
    }

    func signedOut() -> Bool {
        didSignOut
    }
}

private actor SessionCacheSpy: SessionCache {
    private var purged = false
    func purge() async {
        purged = true
    }

    func wasPurged() -> Bool {
        purged
    }
}

private struct PublicBackendStub: PublicBackendServing {
    let event: PublicEventDTO

    func resolveEvent(invocationToken _: String) async throws -> ResolveEventData {
        ResolveEventData(
            event: event,
            legal: PublicLegalDTO(
                termsVersion: "terms-v1",
                termsURL: URL(string: "https://example.invalid/terms")!,
                privacyVersion: "privacy-v1",
                privacyURL: URL(string: "https://example.invalid/privacy")!
            ),
            serverTime: Date(timeIntervalSince1970: 1_800_000_000),
            cacheMaxAgeSeconds: 60
        )
    }

    func createBooking(
        _: CreateBookingRequest,
        idempotencyKey _: String
    ) async throws -> CreateBookingData {
        throw TestFailure.unexpectedCall
    }

    func verifyDonor(bookingId _: String, phone _: String) async throws -> DonorVerificationData {
        throw TestFailure.unexpectedCall
    }

    func donorBookingStatus(accessToken _: String) async throws -> DonorBookingStatusData {
        throw TestFailure.unexpectedCall
    }
}

private extension AdminEvent {
    static func fixture(name: String, version: Int64 = 0) -> AdminEvent {
        AdminEvent(
            name: name,
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_003_600),
            capacityKg: 100,
            collectedKg: 0,
            version: version
        )
    }
}

private extension PublicEventDTO {
    static func fixture() -> PublicEventDTO {
        PublicEventDTO(
            id: UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!,
            name: "Event Test",
            description: "Description",
            status: .ongoing,
            availability: .available,
            startAt: Date(timeIntervalSince1970: 1_800_000_000),
            endAt: Date(timeIntervalSince1970: 1_800_003_600),
            timezoneName: "Asia/Jakarta",
            operationalDays: [1, 2, 3],
            opensAtLocal: "08:00:00",
            closesAtLocal: "17:00:00",
            locationName: "Jakarta",
            locationAddress: "Jl. Test",
            latitude: -6.2,
            longitude: 106.8,
            capacityGrams: 100_000,
            receivedWeightGrams: 1000,
            bannerObjectPath: "workspace/event/banner.jpg",
            receiverName: "Receiver",
            receiverPhone: "+6281234567890",
            receiverAddress: "Jl. Receiver",
            criteria: [.cotton],
            version: 2,
            schemaVersion: 1,
            capturedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
    }
}
