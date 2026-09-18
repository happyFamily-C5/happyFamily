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
        guard let startAt = detail?.event.startAt, let endAt = detail?.event.endAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm"
        formatter.timeZone = TimeZone(identifier: detail?.event.timezoneName ?? "Asia/Jakarta")
        return "\(formatter.string(from: startAt)) - \(formatter.string(from: endAt))"
    }
}
