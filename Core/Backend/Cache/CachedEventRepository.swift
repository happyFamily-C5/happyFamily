import Foundation

/// Adds tenant-scoped SwiftData caching and offline draft retry around the
/// remote repository. Only draft upserts enter the pending queue; every
/// operational mutation remains online-only.
actor CachedEventRepository: EventRepository {
    typealias OwnerUserIdProvider = @Sendable () async throws -> UUID

    private let remote: any EventRepository
    private let store: any EventLocalStore
    private let ownerUserId: OwnerUserIdProvider

    init(
        remote: any EventRepository,
        store: any EventLocalStore,
        ownerUserId: @escaping OwnerUserIdProvider
    ) {
        self.remote = remote
        self.store = store
        self.ownerUserId = ownerUserId
    }

    func list(cursor requestedCursor: String?) async throws -> EventPage {
        let ownerUserId = try await ownerUserId()
        let cachedCursor = try await store.cursor(ownerUserId: ownerUserId)

        do {
            guard try await flushPendingDrafts(ownerUserId: ownerUserId) else {
                return try await cachedPage(
                    ownerUserId: ownerUserId,
                    cursor: requestedCursor ?? cachedCursor
                )
            }

            let page = try await remote.list(cursor: requestedCursor ?? cachedCursor)
            do {
                try await store.cacheRemoteEvents(
                    page.events,
                    cursor: page.cursor,
                    ownerUserId: ownerUserId
                )
                return try await EventPage(
                    events: store.cachedEvents(ownerUserId: ownerUserId),
                    cursor: page.cursor
                )
            } catch {
                // A local cache failure must not hide a successful server read.
                return page
            }
        } catch {
            guard Self.isConnectivityError(error) else { throw error }
            let events = try await store.cachedEvents(ownerUserId: ownerUserId)
            guard !events.isEmpty else { throw error }
            return EventPage(events: events, cursor: requestedCursor ?? cachedCursor)
        }
    }

    func upsertDraft(_ event: AdminEvent, mutationId: UUID) async throws -> AdminEvent {
        guard event.status == .draft else {
            return try await remote.upsertDraft(event, mutationId: mutationId)
        }

        let ownerUserId = try await ownerUserId()
        do {
            try await store.enqueueDraft(
                event,
                mutationId: mutationId,
                ownerUserId: ownerUserId
            )
        } catch {
            // Keep online event creation available even if the local store is
            // unavailable. An offline failure still reaches the caller.
            return try await remote.upsertDraft(event, mutationId: mutationId)
        }

        do {
            let saved = try await remote.upsertDraft(event, mutationId: mutationId)
            try? await store.markDraftSynced(
                saved,
                mutationId: mutationId,
                ownerUserId: ownerUserId
            )
            return saved
        } catch {
            if Self.isConnectivityError(error) {
                return event
            }
            try? await store.discardDraft(
                eventId: event.id,
                mutationId: mutationId,
                ownerUserId: ownerUserId
            )
            throw error
        }
    }

    func publish(eventId: UUID) async throws -> PublishEventData {
        try await remote.publish(eventId: eventId)
    }

    func terminate(
        eventId: UUID,
        status: EventStatusCode,
        reason: String?
    ) async throws -> AdminEvent {
        let event = try await remote.terminate(eventId: eventId, status: status, reason: reason)
        if let ownerUserId = try? await ownerUserId() {
            try? await store.cacheRemoteEvents(
                [event],
                cursor: nil,
                ownerUserId: ownerUserId
            )
        }
        return event
    }

    private func flushPendingDrafts(ownerUserId: UUID) async throws -> Bool {
        for draft in try await store.pendingDrafts(ownerUserId: ownerUserId) {
            do {
                let saved = try await remote.upsertDraft(
                    draft.event,
                    mutationId: draft.mutationId
                )
                try await store.markDraftSynced(
                    saved,
                    mutationId: draft.mutationId,
                    ownerUserId: ownerUserId
                )
            } catch {
                if Self.isConnectivityError(error) {
                    return false
                }
                throw error
            }
        }
        return true
    }

    private func cachedPage(ownerUserId: UUID, cursor: String?) async throws -> EventPage {
        let events = try await store.cachedEvents(ownerUserId: ownerUserId)
        return EventPage(events: events, cursor: cursor)
    }

    private static func isConnectivityError(_ error: Error) -> Bool {
        if case BackendError.transport = error {
            return true
        }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
             .notConnectedToInternet, .timedOut:
            return true
        default:
            return false
        }
    }
}
