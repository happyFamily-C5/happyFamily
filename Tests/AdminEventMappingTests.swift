import CoreLocation
import Foundation
@testable import happyFamily
import Testing

@Suite("Admin event mapping")
struct AdminEventMappingTests {
    private func backendEvent(
        id: UUID = UUID(),
        name: String = "Bersih Kali",
        capacityKg: Int = 10,
        status: EventStatusCode = .draft,
        operationalDays: [Int] = [],
        opensAtLocal: String = "08:00:00",
        closesAtLocal: String = "17:00:00",
        latitude: Double? = nil,
        longitude: Double? = nil,
        criteria: [EventCriterionCode] = []
    ) -> BackendAdminEvent {
        BackendAdminEvent(
            id: id,
            name: name,
            description: "Deskripsi",
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_086_400),
            capacityKg: capacityKg,
            collectedKg: 0,
            status: status,
            timezoneName: "Asia/Jakarta",
            operationalDays: operationalDays,
            opensAtLocal: opensAtLocal,
            closesAtLocal: closesAtLocal,
            latitude: latitude,
            longitude: longitude,
            criteria: criteria,
            maxDonationPerUserKg: 1
        )
    }

    @Test("Criterion labels map to codes and back for all ten criteria")
    func criterionLabelsRoundTrip() {
        #expect(EventCriterionCode.uiLabels == [
            "Katun", "Linen", "Rayon", "Wol",
            "Tencel", "Sutra", "Tidak Elastis",
            "Denim", "Tidak berenda",
            "Poliester",
        ])
        for code in EventCriterionCode.allCases {
            #expect(EventCriterionCode.from(uiLabel: code.uiLabel) == code)
        }
        #expect(EventCriterionCode.from(uiLabel: "Katun") == .cotton)
        #expect(EventCriterionCode.from(uiLabel: "Tidak berenda") == .noLace)
        #expect(EventCriterionCode.from(uiLabel: "Tidak ada") == nil)
    }

    @Test("Weekend operational days map to UI activeDays and back")
    func weekendDaysRoundTrip() {
        let fromBackend = AdminEvent(backend: backendEvent(operationalDays: [6, 7]))
        #expect(fromBackend.activeDays == [false, false, false, false, false, true, true])
        #expect(fromBackend.operationalMode == "Akhir Pekan")
        #expect(fromBackend.toBackendAdminEvent().operationalDays == [6, 7])
    }

    @Test("Weekday operational days map to UI activeDays")
    func weekdayDaysMapping() {
        let fromBackend = AdminEvent(backend: backendEvent(operationalDays: [1, 2, 3, 4, 5]))
        #expect(fromBackend.activeDays == [true, true, true, true, true, false, false])
        #expect(fromBackend.operationalMode == "Hari Kerja")
        #expect(fromBackend.toBackendAdminEvent().operationalDays == [1, 2, 3, 4, 5])
    }

    @Test("Every day and custom selections derive preset labels")
    func operationalModeDerivation() {
        #expect(AdminEvent(backend: backendEvent(operationalDays: [1, 2, 3, 4, 5, 6, 7])).operationalMode == "Setiap Hari")
        #expect(AdminEvent(backend: backendEvent(operationalDays: [2, 6])).operationalMode == "Hari Kustom")
        #expect(AdminEvent(backend: backendEvent(operationalDays: [])).operationalMode == "Hari Kustom")
    }

    @Test("Kilograms are wire-encoded as grams for capacity and donation limit")
    func kilogramsEncodeAsGrams() {
        let event = AdminEvent(backend: backendEvent(capacityKg: 10))
        let payload = EventDraftPayload(event: event.toBackendAdminEvent())
        #expect(payload.capacityGrams == 10000)
        #expect(payload.maxDonationPerUserGrams == 1000)
    }

    @Test("Local schedule strings parse into today's hour and minute")
    func localTimesParse() {
        let event = AdminEvent(backend: backendEvent(opensAtLocal: "08:00:00", closesAtLocal: "17:30:00"))
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: event.startTime)
        let end = calendar.dateComponents([.hour, .minute], from: event.endTime)
        #expect(start.hour == 8 && start.minute == 0)
        #expect(end.hour == 17 && end.minute == 30)
        let rewritten = event.toBackendAdminEvent()
        #expect(rewritten.opensAtLocal == "08:00:00")
        #expect(rewritten.closesAtLocal == "17:30:00")
    }

    @Test("Fallback schedule applies when the server omits local times")
    func fallbackScheduleApplied() {
        let event = AdminEvent(backend: backendEvent(opensAtLocal: "", closesAtLocal: ""))
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: event.startTime)
        let end = calendar.dateComponents([.hour, .minute], from: event.endTime)
        #expect(start.hour == 8 && end.hour == 17)
    }

    @Test("Mapped events always publish in Asia/Jakarta")
    func timezoneHardcoded() {
        #expect(AdminEvent(backend: backendEvent()).toBackendAdminEvent().timezoneName == "Asia/Jakarta")
    }

    @Test("Absent coordinates stay absent in the UI model")
    func missingCoordinateStaysNil() {
        #expect(AdminEvent(backend: backendEvent()).coordinate == nil)
        let withCoordinate = AdminEvent(
            backend: backendEvent(latitude: -6.2, longitude: 106.8)
        )
        #expect(withCoordinate.coordinate?.latitude == -6.2)
        #expect(withCoordinate.coordinate?.longitude == 106.8)
    }

    @Test("Roundtrip preserves identity, criteria, and dates")
    func roundTripPreservesCoreFields() {
        let original = backendEvent(
            criteria: [.cotton, .denim, .noLace, .polyester]
        )
        let ui = AdminEvent(backend: original)
        let back = ui.toBackendAdminEvent()

        #expect(back.id == original.id)
        #expect(back.name == original.name)
        #expect(back.description == original.description)
        #expect(back.startDate == original.startDate)
        #expect(back.endDate == original.endDate)
        #expect(back.capacityKg == original.capacityKg)
        #expect(back.status == .draft)
        #expect(back.criteria == original.criteria)
        #expect(back.maxDonationPerUserKg == original.maxDonationPerUserKg)
        #expect(back.receiverName == nil)
        #expect(back.receiverPhone == nil)
        #expect(back.receiverAddress == nil)
        #expect(AdminEvent(backend: back).donationCriteria == ui.donationCriteria)
    }

    @Test("Event status survives the UI mapping in both directions")
    func statusRoundTrips() {
        let fromBackend = AdminEvent(backend: backendEvent(status: .upcoming))
        #expect(fromBackend.status == .upcoming)
        #expect(fromBackend.toBackendAdminEvent().status == .upcoming)
    }
}
