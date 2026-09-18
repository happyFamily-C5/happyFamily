import Foundation
import Observation

/// Loads `account:event_detail` for a single donor event, including donor
/// availability and the environment's active legal documents.
@MainActor
@Observable
final class DonorEventDetailModel {
    private(set) var detail: DonorEventDetail?
    private(set) var isLoading = false
    var errorMessage: String?

    private let eventId: UUID
    private let accountClient: (any AccountBackendServing)?
    private let backendBaseURL: URL?

    init(
        eventId: UUID,
        accountClient: (any AccountBackendServing)?,
        backendBaseURL: URL? = nil
    ) {
        self.eventId = eventId
        self.accountClient = accountClient
        self.backendBaseURL = backendBaseURL
    }

    func load() async {
        guard let accountClient else {
            errorMessage = "Backend belum dikonfigurasi"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await accountClient.eventDetail(id: eventId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bannerURL() -> URL? {
        EventBannerURLBuilder.makeURL(
            baseURL: backendBaseURL,
            objectPath: detail?.event.bannerObjectPath
        )
    }

    /// "09.00 - 16.00" style operating window from the event schedule.
    var timeInfoText: String? {
        guard let event = detail?.event else { return nil }
        return DonorEventScheduleFormatter.operationalTimeInfoText(event)
    }
}

enum DonorEventScheduleFormatter {
    private static let fallbackTimeZone = TimeZone(identifier: "Asia/Jakarta")!

    static func dateRangeText(_ event: DonorEventDTO) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        formatter.timeZone = event.timezoneName.flatMap(TimeZone.init(identifier:)) ?? fallbackTimeZone

        switch (event.startAt, event.endAt) {
        case let (start?, end?):
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case let (start?, nil):
            return formatter.string(from: start)
        case let (nil, end?):
            return formatter.string(from: end)
        default:
            return "-"
        }
    }

    static func operationalTimeInfoText(_ event: DonorEventDTO) -> String? {
        guard let opensAt = formattedLocalTime(event.opensAtLocal),
              let closesAt = formattedLocalTime(event.closesAtLocal)
        else { return nil }

        let timeRange = "\(opensAt) - \(closesAt)"
        guard let days = event.operationalDays, !days.isEmpty else { return timeRange }
        return "\(operationalMode(for: days)) • \(timeRange)"
    }

    private static func formattedLocalTime(_ value: String?) -> String? {
        guard let value else { return nil }
        let components = value.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]), (0 ... 23).contains(hour),
              let minute = Int(components[1]), (0 ... 59).contains(minute)
        else { return nil }
        return String(format: "%02d.%02d", hour, minute)
    }

    private static func operationalMode(for days: [Int]) -> String {
        let values = Set(days)
        if values == Set(1 ... 5) {
            return "Hari Kerja"
        }
        if values == Set([6, 7]) {
            return "Akhir Pekan"
        }
        if values == Set(1 ... 7) {
            return "Setiap Hari"
        }
        return "Hari Kustom"
    }
}
