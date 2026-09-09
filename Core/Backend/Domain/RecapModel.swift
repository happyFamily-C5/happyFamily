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
/// Totals come from the `recap_v1` RPC; per-donation rows come from the
/// organizer `export-report` edge function (which decrypts donor PII).
@MainActor
@Observable
final class RecapModel {
    private(set) var recap: RecapData?
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

            let rows = try await recentBookingRows()
            self.recentDonations = rows

            errorMessage = nil
            isDataEmpty = recap.acceptedBookingCount == 0
                && recap.completedEventCount == 0
                && recap.totalAcceptedWeightGrams == 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Total collected weight formatted for the recap card ("1,2 kg").
    var totalWeightText: String {
        let kilograms = Double(recap?.totalAcceptedWeightGrams ?? 0) / 1000
        return String(format: "%.1f kg", kilograms)
    }

    var collectedKgText: String {
        String(format: "%.0f", Double(recap?.totalAcceptedWeightGrams ?? 0) / 1000)
    }

    var donorCountText: String {
        String(recap?.uniqueDonorCount ?? 0)
    }

    var completedEventCountText: String {
        String(recap?.completedEventCount ?? 0)
    }

    var averagePerDonationText: String {
        let donorCount = Int(recap?.uniqueDonorCount ?? 0)
        guard donorCount > 0 else { return "0" }
        let averageGrams = Double(recap?.totalAcceptedWeightGrams ?? 0) / Double(donorCount)
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

    private func recentBookingRows() async throws -> [RecentDonation] {
        guard let reportRepository else { return [] }
        let createdFrom = Calendar.current.date(byAdding: .day, value: -30, to: .now)
        let csv = try await reportRepository.exportCSV(
            filter: ReportFilter(eventId: nil, createdFrom: createdFrom, createdTo: nil)
        )
        return Self.parseRecentDonations(from: csv, limit: 5)
    }

    /// Parses the BOM-prefixed CSV produced by the export-report edge function.
    /// Header: booking_id,event_name,booking_time,status,estimated_weight_grams,
    /// actual_weight_grams,condition,rejection_reason,shipping_method,donor_name,donor_phone
    static func parseRecentDonations(from data: Data, limit: Int) -> [RecentDonation] {
        guard let raw = String(data: data, encoding: .utf8) else { return [] }
        let text = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw

        var rows: [RecentDonation] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in text.split(separator: "\r\n").dropFirst() {
            let fields = parseCSVLine(String(line))
            guard fields.count >= 11 else { continue }
            let status = fields[3]
            // Accepted receptions carry an actual weight; pending rows only
            // estimate. Show only donations that have been received.
            let actualWeight = Int64(fields[5]) ?? 0
            guard status == "received", actualWeight > 0 else { continue }
            guard let createdAt = dateFormatter.date(from: fields[2]) else { continue }
            rows.append(
                RecentDonation(
                    id: fields[0],
                    donorName: fields[9],
                    createdAt: createdAt,
                    weightGrams: actualWeight
                )
            )
        }

        return Array(rows.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        var iterator = line.makeIterator()
        while let character = iterator.next() {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == ",", !insideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        fields.append(current)
        return fields
    }
}
