import Foundation
import SwiftData

enum EventCacheSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [CachedEvent.self, PendingDraft.self, SyncState.self]
    }

    @Model
    final class CachedEvent {
        @Attribute(.unique) var scopedId: String
        var ownerUserId: UUID
        var eventId: UUID
        var payload: Data
        @Attribute(.externalStorage) var bannerImageData: Data?
        var sortDate: Date
        var refreshedAt: Date

        init(ownerUserId: UUID, event: BackendAdminEvent, payload: Data) {
            scopedId = Self.scopedId(ownerUserId: ownerUserId, eventId: event.id)
            self.ownerUserId = ownerUserId
            eventId = event.id
            self.payload = payload
            bannerImageData = event.bannerImageData
            sortDate = event.startDate
            refreshedAt = .now
        }

        static func scopedId(ownerUserId: UUID, eventId: UUID) -> String {
            "\(ownerUserId.uuidString.lowercased()):\(eventId.uuidString.lowercased())"
        }
    }

    @Model
    final class PendingDraft {
        @Attribute(.unique) var scopedId: String
        var ownerUserId: UUID
        var eventId: UUID
        var mutationId: UUID
        var payload: Data
        @Attribute(.externalStorage) var bannerImageData: Data?
        var enqueuedAt: Date

        init(ownerUserId: UUID, event: BackendAdminEvent, mutationId: UUID, payload: Data) {
            scopedId = CachedEvent.scopedId(ownerUserId: ownerUserId, eventId: event.id)
            self.ownerUserId = ownerUserId
            eventId = event.id
            self.mutationId = mutationId
            self.payload = payload
            bannerImageData = event.bannerImageData
            enqueuedAt = .now
        }
    }

    @Model
    final class SyncState {
        @Attribute(.unique) var ownerUserId: UUID
        var cursor: String?

        init(ownerUserId: UUID, cursor: String?) {
            self.ownerUserId = ownerUserId
            self.cursor = cursor
        }
    }
}

enum EventCacheMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [EventCacheSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

@ModelActor
actor SwiftDataEventStore: EventLocalStore {
    nonisolated static func make(isStoredInMemoryOnly: Bool = false) throws -> SwiftDataEventStore {
        let schema = Schema(versionedSchema: EventCacheSchemaV1.self)
        let configuration = ModelConfiguration(
            "KumpulEventCache",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: EventCacheMigrationPlan.self,
            configurations: [configuration]
        )
        return SwiftDataEventStore(modelContainer: container)
    }

    func cachedEvents(ownerUserId: UUID) throws -> [BackendAdminEvent] {
        let descriptor = FetchDescriptor<EventCacheSchemaV1.CachedEvent>(
            predicate: #Predicate { $0.ownerUserId == ownerUserId },
            sortBy: [SortDescriptor(\.sortDate)]
        )
        return try modelContext.fetch(descriptor).compactMap { record in
            try? EventCacheCodec.decode(record.payload, bannerImageData: record.bannerImageData)
        }
    }

    func cursor(ownerUserId: UUID) throws -> String? {
        try syncState(ownerUserId: ownerUserId)?.cursor
    }

    func cacheRemoteEvents(
        _ events: [BackendAdminEvent],
        cursor: String?,
        ownerUserId: UUID
    ) throws {
        for event in events where try pendingDraft(ownerUserId: ownerUserId, eventId: event.id) == nil {
            try upsertCachedEvent(event, ownerUserId: ownerUserId)
        }

        if let state = try syncState(ownerUserId: ownerUserId) {
            if let cursor {
                state.cursor = cursor
            }
        } else {
            modelContext.insert(EventCacheSchemaV1.SyncState(
                ownerUserId: ownerUserId,
                cursor: cursor
            ))
        }
        try modelContext.save()
    }

    func enqueueDraft(
        _ event: BackendAdminEvent,
        mutationId: UUID,
        ownerUserId: UUID
    ) throws {
        let payload = try EventCacheCodec.encode(event)
        if let pending = try pendingDraft(ownerUserId: ownerUserId, eventId: event.id) {
            pending.mutationId = mutationId
            pending.payload = payload
            pending.bannerImageData = event.bannerImageData
            pending.enqueuedAt = .now
        } else {
            modelContext.insert(EventCacheSchemaV1.PendingDraft(
                ownerUserId: ownerUserId,
                event: event,
                mutationId: mutationId,
                payload: payload
            ))
        }
        try upsertCachedEvent(event, ownerUserId: ownerUserId, payload: payload)
        try modelContext.save()
    }

    func pendingDrafts(ownerUserId: UUID) throws -> [PendingDraftSync] {
        let descriptor = FetchDescriptor<EventCacheSchemaV1.PendingDraft>(
            predicate: #Predicate { $0.ownerUserId == ownerUserId },
            sortBy: [SortDescriptor(\.enqueuedAt)]
        )
        return try modelContext.fetch(descriptor).compactMap { record in
            guard let event = try? EventCacheCodec.decode(
                record.payload,
                bannerImageData: record.bannerImageData
            ) else {
                return nil
            }
            return PendingDraftSync(event: event, mutationId: record.mutationId)
        }
    }

    func markDraftSynced(
        _ event: BackendAdminEvent,
        mutationId: UUID,
        ownerUserId: UUID
    ) throws {
        guard let pending = try pendingDraft(ownerUserId: ownerUserId, eventId: event.id),
              pending.mutationId == mutationId
        else {
            return
        }
        modelContext.delete(pending)
        try upsertCachedEvent(event, ownerUserId: ownerUserId)
        try modelContext.save()
    }

    func discardDraft(
        eventId: UUID,
        mutationId: UUID,
        ownerUserId: UUID
    ) throws {
        guard let pending = try pendingDraft(ownerUserId: ownerUserId, eventId: eventId),
              pending.mutationId == mutationId
        else {
            return
        }
        modelContext.delete(pending)
        try modelContext.save()
    }

    func purge() {
        do {
            for record in try modelContext.fetch(FetchDescriptor<EventCacheSchemaV1.CachedEvent>()) {
                modelContext.delete(record)
            }
            for record in try modelContext.fetch(FetchDescriptor<EventCacheSchemaV1.PendingDraft>()) {
                modelContext.delete(record)
            }
            for record in try modelContext.fetch(FetchDescriptor<EventCacheSchemaV1.SyncState>()) {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            // Logout remains best-effort after the server invalidates sessions;
            // the tenant-scoped keys still prevent another account reading rows.
        }
    }

    private func upsertCachedEvent(
        _ event: BackendAdminEvent,
        ownerUserId: UUID,
        payload suppliedPayload: Data? = nil
    ) throws {
        let payload = try suppliedPayload ?? EventCacheCodec.encode(event)
        if let cached = try cachedEvent(ownerUserId: ownerUserId, eventId: event.id) {
            cached.payload = payload
            cached.bannerImageData = event.bannerImageData
            cached.sortDate = event.startDate
            cached.refreshedAt = .now
        } else {
            modelContext.insert(EventCacheSchemaV1.CachedEvent(
                ownerUserId: ownerUserId,
                event: event,
                payload: payload
            ))
        }
    }

    private func cachedEvent(
        ownerUserId: UUID,
        eventId: UUID
    ) throws -> EventCacheSchemaV1.CachedEvent? {
        let scopedId = EventCacheSchemaV1.CachedEvent.scopedId(
            ownerUserId: ownerUserId,
            eventId: eventId
        )
        var descriptor = FetchDescriptor<EventCacheSchemaV1.CachedEvent>(
            predicate: #Predicate { $0.scopedId == scopedId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func pendingDraft(
        ownerUserId: UUID,
        eventId: UUID
    ) throws -> EventCacheSchemaV1.PendingDraft? {
        let scopedId = EventCacheSchemaV1.CachedEvent.scopedId(
            ownerUserId: ownerUserId,
            eventId: eventId
        )
        var descriptor = FetchDescriptor<EventCacheSchemaV1.PendingDraft>(
            predicate: #Predicate { $0.scopedId == scopedId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func syncState(ownerUserId: UUID) throws -> EventCacheSchemaV1.SyncState? {
        var descriptor = FetchDescriptor<EventCacheSchemaV1.SyncState>(
            predicate: #Predicate { $0.ownerUserId == ownerUserId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

private enum EventCacheCodec {
    static func encode(_ event: BackendAdminEvent) throws -> Data {
        var event = event
        event.bannerImageData = nil
        return try JSONEncoder().encode(event)
    }

    static func decode(_ payload: Data, bannerImageData: Data?) throws -> BackendAdminEvent {
        var event = try JSONDecoder().decode(BackendAdminEvent.self, from: payload)
        event.bannerImageData = bannerImageData
        return event
    }
}
