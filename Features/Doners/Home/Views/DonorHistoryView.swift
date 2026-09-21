//
//  DonorHistoryView.swift
//  happyFamily
//
//  Created by EcoTouch on 09/09/26.
//

import SwiftUI

/// Donor history surface: `account:donation_history` (received donations)
/// and `account:event_history` with the terminal filter (finished
/// lifecycles), both cursor paginated.
struct DonorHistoryView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case donations = "Donasi"
        case completed = "Selesai"

        var id: String {
            rawValue
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State private var segment: Segment = .donations
    @State private var model = DonorHistoryModel(
        accountClient: BackendDependencies.accountClientOrDefault()
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Riwayat")
                    .font(.system(size: 26, weight: .bold))
                    .padding(.horizontal, 20)

                Picker("Segmen", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                segmentContent
            }
            .padding(.top, 18)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Kembali")
            }
        }
        .task {
            await model.loadDonations()
            await model.loadCompleted()
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch segment {
        case .donations:
            historyList(HistorySection(
                items: model.donations,
                isLoading: model.isLoadingDonations,
                isLoadingMore: model.isLoadingMoreDonations,
                errorMessage: model.donationError,
                hasMore: model.hasMoreDonations,
                emptyTitle: "Belum Ada Riwayat Donasi",
                emptyMessage: "Donasi yang telah diterima akan tampil di halaman ini",
                load: { await model.loadDonations() },
                loadMore: { await model.loadMoreDonations() }
            ))
        case .completed:
            historyList(HistorySection(
                items: model.completed,
                isLoading: model.isLoadingCompleted,
                isLoadingMore: model.isLoadingMoreCompleted,
                errorMessage: model.completedError,
                hasMore: model.hasMoreCompleted,
                emptyTitle: "Belum Ada Riwayat Selesai",
                emptyMessage: "Acara yang telah selesai akan tampil di halaman ini",
                load: { await model.loadCompleted() },
                loadMore: { await model.loadMoreCompleted() }
            ))
        }
    }

    private struct HistorySection {
        let items: [BookingHistoryItem]
        let isLoading: Bool
        let isLoadingMore: Bool
        let errorMessage: String?
        let hasMore: Bool
        let emptyTitle: String
        let emptyMessage: String
        let load: () async -> Void
        let loadMore: () async -> Void
    }

    private func historyList(_ section: HistorySection) -> some View {
        let items = section.items
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = section.errorMessage, items.isEmpty {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Coba lagi") {
                            Task { await section.load() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                } else if section.isLoading, items.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(0 ..< 3, id: \.self) { _ in
                            DonorHistoryRowSkeleton()
                        }
                    }
                    .padding(.horizontal, 20)
                    .skeleton(isLoading: true)
                } else if items.isEmpty {
                    DonorEmptyHistoryView(
                        systemImage: "clock.arrow.circlepath",
                        title: section.emptyTitle,
                        message: section.emptyMessage
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                } else {
                    VStack(spacing: 12) {
                        ForEach(items) { item in
                            historyRow(item)
                                .onAppear {
                                    if item.id == items.last?.id, section.hasMore {
                                        Task { await section.loadMore() }
                                    }
                                }
                        }
                        if section.isLoadingMore {
                            DonorHistoryRowSkeleton()
                                .skeleton(isLoading: true)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private func historyRow(_ item: BookingHistoryItem) -> some View {
        Button {
            router.push(to: .bookingDetail(item.bookingId))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.event.name ?? item.publicBookingId)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(Self.dateText(from: item.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Self.statusLabel(item.status))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15), in: Capsule())

                    Text(Self.weightText(grams: item.actualWeightGrams ?? item.estimatedWeightGrams))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color("3-DarkSoftCyan"))
                }
            }
            .padding(14)
            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private static func statusLabel(_ status: BookingStatusCode) -> String {
        switch status {
        case .waiting: "Menunggu"
        case .accepted: "Diterima"
        case .processed: "Diproses"
        case .recycled: "Didaur Ulang"
        case .rejected: "Ditolak"
        case .expired: "Kedaluwarsa"
        case .cancelled: "Dibatalkan"
        }
    }

    private static func weightText(grams: Int64) -> String {
        String(format: "%.1f kg", Double(grams) / 1000)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static func dateText(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

private struct DonorHistoryRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 155, height: 15)
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 100, height: 12)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 7) {
                SkeletonBlock(cornerRadius: 10)
                    .frame(width: 70, height: 18)
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 48, height: 14)
            }
        }
        .padding(14)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DonorEmptyHistoryView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 58, weight: .regular))
                .foregroundColor(Color("3-DarkSoftCyan"))

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DonorHistoryView()
    }
}
