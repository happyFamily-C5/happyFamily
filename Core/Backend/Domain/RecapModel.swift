import Foundation
import Observation

/// One recent donation row rendered by `DonationRowView`.
struct RecentDonation: Identifiable, Equatable, Sendable {
    let id: String
    let donorName: String
    let createdAt: Date
    let weightGrams: Int64

    var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: .now)
    }

    var weightText: String {
        let kilograms = Double(weightGrams) / 1000
        return String(format: "%.1f kg", kilograms)
    }
}

/// One daily bar in the recap chart. `weightGrams` is the aggregated
/// collected weight; the chart view scales bar heights relative to the
/// maximum.
struct DonationChartBar: Equatable, Sendable {
    let dayLabel: String
    let weightGrams: Int64
}

/// Loads and aggregates recap data for the recap surfaces.
/// Totals and recent rows come from `operations:recap`; no CSV export is
/// fetched merely to render a screen containing donor PII.
@MainActor
@Observable
final class RecapModel {
    private(set) var recap: AdminRecapData?
    private(set) var recentDonations: [RecentDonation] = []
    private(set) var isLoading = false
    private(set) var isDataEmpty = true
    var errorMessage: String?

    private let reportRepository: (any ReportRepository)?

    init(reportRepository: (any ReportRepository)?) {
        self.reportRepository = reportRepository
        self.isDataEmpty = true
    }

    func load() async {
        guard let reportRepository else {
            errorMessage = "Konfigurasi backend belum lengkap."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let recap = try await reportRepository.recap(eventId: nil)
            self.recap = recap

            self.recentDonations = recap.recentDonations.map {
                RecentDonation(
                    id: $0.bookingId.uuidString,
                    donorName: $0.donorName ?? "Donatur",
                    createdAt: $0.receivedAt,
                    weightGrams: $0.actualWeightGrams
                )
            }

            errorMessage = nil
            isDataEmpty = recap.month.acceptedCount == 0
                && recap.month.acceptedWeightGrams == 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Total collected weight formatted for the recap card ("1,2 kg").
    var totalWeightText: String {
        let kilograms = Double(recap?.month.acceptedWeightGrams ?? 0) / 1000
        return String(format: "%.1f kg", kilograms)
    }

    var collectedKgText: String {
        String(format: "%.0f", Double(recap?.month.acceptedWeightGrams ?? 0) / 1000)
    }

    var donorCountText: String {
        String(recap?.month.uniqueDonorCount ?? 0)
    }

    var averagePerDonationText: String {
        let donorCount = Int(recap?.month.uniqueDonorCount ?? 0)
        guard donorCount > 0 else { return "0" }
        let averageGrams = Double(recap?.month.acceptedWeightGrams ?? 0) / Double(donorCount)
        return String(format: "%.1f", averageGrams / 1000)
    }

    /// Daily aggregation for the last 7 days, oldest first (Sen..Min).
    var dailyChartData: [DonationChartBar] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "id_ID")
        dayFormatter.dateFormat = "EEE"

        var buckets: [Date: Int64] = [:]
        for donation in recentDonations {
            let day = calendar.startOfDay(for: donation.createdAt)
            buckets[day, default: 0] += donation.weightGrams
        }

        return (-6 ... 0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            return DonationChartBar(
                dayLabel: dayFormatter.string(from: day),
                weightGrams: buckets[day] ?? 0
            )
        }
    }

    /// Chart tuples consumed directly by DonationBarChartView. Bar heights
    /// are normalized into the 40-130 pt range the card design uses, and the
    /// heaviest day gets the "X kg" tooltip.
    var dailyChartTuples: [(day: String, height: CGFloat, weightLabel: String?)] {
        let bars = dailyChartData
        guard !bars.isEmpty else { return [] }
        let maxGrams = bars.map(\.weightGrams).max() ?? 0
        let minHeight: CGFloat = 40
        let maxHeight: CGFloat = 130
        return bars.map { bar in
            let height: CGFloat
            if maxGrams <= 0 {
                height = minHeight
            } else {
                let ratio = CGFloat(bar.weightGrams) / CGFloat(maxGrams)
                height = minHeight + ratio * (maxHeight - minHeight)
            }
            let isPeak = bar.weightGrams == maxGrams && maxGrams > 0
            return (
                day: bar.dayLabel,
                height: height,
                weightLabel: isPeak ? String(format: "%.1f kg", Double(bar.weightGrams) / 1000) : nil
            )
        }
    }
}
