import Foundation
import Observation

extension Notification.Name {
    /// Emitted after an Admin mutation changes event capacity, reception, or
    /// tracking totals that are also rendered by the dashboard recap.
    static let adminOperationsDidChange = Notification.Name("adminOperationsDidChange")
}

@MainActor
@Observable
final class DashboardModel {
    private(set) var events: [BackendAdminEvent] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var nextCursor: String?
    private(set) var recap: AdminRecapData?
    private(set) var isRecapLoading = false
    var errorMessage: String?

    /// Invocation URL of the most recent successful publish; nil until a
    /// publish succeeds in this session.
    private(set) var publishedInvocationURL: URL?

    private let repository: any EventRepository
    private let reportRepository: (any ReportRepository)?
    private var backendBaseURL: URL?
    private var pendingDraftMutationIds: [UUID: UUID] = [:]

    init(
        repository: any EventRepository,
        reportRepository: (any ReportRepository)? = nil,
        backendBaseURL: URL? = nil
    ) {
        self.repository = repository
        self.reportRepository = reportRepository
        self.backendBaseURL = backendBaseURL
    }

    /// True when recap totals are absent (nothing collected yet).
    var isRecapDataEmpty: Bool {
        guard let recap else { return true }
        return recap.month.acceptedCount == 0
            && recap.month.acceptedWeightGrams == 0
    }

    /// Total collected weight formatted in Indonesian kilograms ("1.045 kg").
    var recapTotalWeightText: String {
        let kilograms = Double(recap?.month.acceptedWeightGrams ?? 0) / 1000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 1
        let text = formatter.string(from: NSNumber(value: kilograms)) ?? "\(kilograms)"
        return "\(text) kg"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await repository.list(cursor: nil)
            events = page.events
            nextCursor = page.cursor
            errorMessage = nil
            await preloadMissingBanners()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard let nextCursor, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await repository.list(cursor: nextCursor)
            let known = Set(events.map(\.id))
            events.append(contentsOf: page.events.filter { !known.contains($0.id) })
            self.nextCursor = page.cursor
            errorMessage = nil
            await preloadMissingBanners()
        } catch BackendError.api(let code, _, _, _) where code == "CURSOR_INVALID" {
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadRecap() async {
        guard let reportRepository else { return }
        isRecapLoading = true
        defer { isRecapLoading = false }
        do {
            recap = try await reportRepository.recap(eventId: nil)
        } catch {
            // Recap is a secondary surface; a failure leaves the previous
            // value (or the empty state) intact without alarming the user.
        }
    }

    /// Downloads banners for events that only carry a `banner_object_path`
    /// (e.g. published remotely) so `bannerImage` can render them offline.
    private func preloadMissingBanners() async {
        guard let backendBaseURL else { return }
        let storageBase = backendBaseURL
            .appending(path: "storage/v1/object/public/event-banners", directoryHint: .isDirectory)
        for index in events.indices {
            guard events[index].bannerImageData == nil,
                  let path = events[index].bannerObjectPath else { continue }
            let url = storageBase.appending(path: path)
            if let (data, _) = try? await URLSession.shared.data(from: url), !data.isEmpty {
                events[index].bannerImageData = data
            }
        }
    }

    @discardableResult
    func createDraft(_ event: BackendAdminEvent) async -> Bool {
        let mutationId = pendingDraftMutationIds[event.id] ?? UUID()
        pendingDraftMutationIds[event.id] = mutationId
        do {
            let saved = try await repository.upsertDraft(event, mutationId: mutationId)
            pendingDraftMutationIds.removeValue(forKey: event.id)
            if let index = events.firstIndex(where: { $0.id == saved.id }) {
                events[index] = saved
            } else {
                events.append(saved)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func cancelOrDelete(_ eventId: UUID) async -> Bool {
        do {
            _ = try await repository.cancelOrDelete(eventId: eventId)
            events.removeAll { $0.id == eventId }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func publish(_ eventId: UUID) async -> Bool {
        publishedInvocationURL = nil
        do {
            let published = try await repository.publish(eventId: eventId)
            publishedInvocationURL = published.invocationURL
            await load()
            await refreshRecap()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Re-runs recap aggregation after a mutation (draft/publish/etc.).
    func refreshRecap() async {
        await loadRecap()
    }
}
