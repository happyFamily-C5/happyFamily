import Foundation
@testable import happyFamily
import Testing

@Suite("Booking attempt store", .serialized)
struct BookingAttemptStoreTests {
    private func makeStore() -> BookingAttemptStore {
        let name = "test-booking-attempts-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return BookingAttemptStore(defaults: defaults)
    }

    @Test("resolveAttempt reuses the stored key for an identical payload")
    func reusesKeyForIdenticalPayload() throws {
        let store = makeStore()
        let eventId = UUID()
        let payload = try bookingBodyPayload(bookingBody())

        let first = store.resolveAttempt(eventId: eventId, payload: payload)
        let second = store.resolveAttempt(eventId: eventId, payload: payload)

        #expect(first.idempotencyKey == second.idempotencyKey)
        #expect(store.pending()?.idempotencyKey == first.idempotencyKey)
    }

    @Test("resolveAttempt generates a new key when the payload changes")
    func newKeyForChangedPayload() throws {
        let store = makeStore()
        let eventId = UUID()
        let original = bookingBody()
        let first = try store.resolveAttempt(eventId: eventId, payload: bookingBodyPayload(original))

        var changed = original
        changed = AccountBookingBody(
            estimatedWeightGrams: 2000,
            itemCount: original.itemCount,
            items: original.items,
            shippingMethod: original.shippingMethod,
            scanModelVersion: original.scanModelVersion
        )
        let second = try store.resolveAttempt(eventId: eventId, payload: bookingBodyPayload(changed))

        #expect(first.idempotencyKey != second.idempotencyKey)
    }

    @Test("resolveAttempt keys per event and clear removes the attempt")
    func perEventAndClear() throws {
        let store = makeStore()
        let payload = try bookingBodyPayload(bookingBody())

        let first = store.resolveAttempt(eventId: UUID(), payload: payload)
        let other = store.resolveAttempt(eventId: UUID(), payload: payload)
        #expect(first.idempotencyKey != other.idempotencyKey)

        store.clear()
        #expect(store.pending() == nil)
    }

    private func bookingBody() -> AccountBookingBody {
        AccountBookingBody(
            estimatedWeightGrams: 500,
            itemCount: 1,
            items: [AccountBookingItem(ordinal: 0, passed: true, scannerModelVersion: "accessory-head-v1", metadata: [:])],
            shippingMethod: .direct,
            scanModelVersion: "accessory-head-v1"
        )
    }
}
