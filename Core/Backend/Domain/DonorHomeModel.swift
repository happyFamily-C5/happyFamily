import Foundation
import Observation

/// Loads the donor home surface: `account:dashboard` rails plus banner URL
/// building for remote event banners.
@MainActor
@Observable
final class DonorHomeModel {
    private(set) var dashboard: DonorDashboardData?
    private(set) var isLoading = false
    var errorMessage: String?

    private let accountClient: (any AccountBackendServing)?
    private let backendBaseURL: URL?

    init(accountClient: (any AccountBackendServing)?, backendBaseURL: URL? = nil) {
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
            dashboard = try await accountClient.dashboard()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bannerURL(for event: DonorEventDTO) -> URL? {
        guard let backendBaseURL, let path = event.bannerObjectPath, !path.isEmpty else { return nil }
        return backendBaseURL
            .appending(path: "storage/v1/object/public/event-banners", directoryHint: .isDirectory)
            .appending(path: path)
    }

    func distanceText(for event: DonorEventDTO) -> String? {
        guard let distanceKm = event.distanceKm, distanceKm > 0 else { return nil }
        return String(format: "%.1f km", distanceKm)
    }
}
