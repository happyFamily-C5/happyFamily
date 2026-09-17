import SwiftUI

/// Donor "Riwayat Acara": rows come from `account:event_history` (terminal
/// lifecycle), grouped into active and past events by the snapshot dates.
struct DonorEventHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let history: [BookingHistoryItem]
    let bannerURL: (BookingHistoryItem) -> URL?

    private var activeEvents: [BookingHistoryItem] {
        history.filter { item in
            guard let end = item.event.endAt else { return true }
            return end >= Date()
        }
    }

    private var pastEvents: [BookingHistoryItem] {
        history.filter { item in
            guard let end = item.event.endAt else { return false }
            return end < Date()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat Acara")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)

                    if history.isEmpty {
                        ProfileEmptyHistoryView(
                            systemImage: "calendar.badge.exclamationmark",
                            title: "Belum Ada Riwayat Acara",
                            message: "Acara yang kamu ikuti akan tampil\ndi halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        if !activeEvents.isEmpty {
                            DonorEventSection(
                                title: "Acara Aktif",
                                history: activeEvents,
                                bannerURL: bannerURL
                            )
                        }

                        if !pastEvents.isEmpty {
                            DonorEventSection(
                                title: "Acara Sebelumnya",
                                history: pastEvents,
                                bannerURL: bannerURL
                            )
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

private struct DonorEventHistoryRow: View {
    let item: BookingHistoryItem
    let bannerURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            banner
                .frame(width: 78, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.event.name ?? "Acara tanpa nama")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(dateRangeText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let bannerURL {
            AsyncImage(url: bannerURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image("DummyImageBanner")
            .resizable()
            .scaledToFill()
    }

    private var dateRangeText: String {
        switch (item.event.startAt, item.event.endAt) {
        case let (start?, end?):
            "\(Self.dayText(start)) – \(Self.dayText(end))"
        case let (start?, nil):
            Self.dayText(start)
        case let (nil, end?):
            Self.dayText(end)
        case (nil, nil):
            "-"
        }
    }

    private static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private struct DonorEventSection: View {
    let title: String
    let history: [BookingHistoryItem]
    let bannerURL: (BookingHistoryItem) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                ForEach(history) { item in
                    DonorEventHistoryRow(item: item, bannerURL: bannerURL(item))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// Donor "Riwayat Donasi": rows come from `account:donation_history`
/// (bookings that reached reception) with the server-owned weight.
struct DonorDonationHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let donations: [BookingHistoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat Donasi")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)

                    if donations.isEmpty {
                        ProfileEmptyHistoryView(
                            systemImage: "list.clipboard",
                            title: "Belum Ada Riwayat Donasi",
                            message: "Donasi yang telah kamu berikan\nakan tampil di halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        VStack(spacing: 18) {
                            ForEach(donations) { donation in
                                DonorDonationRow(donation: donation)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

private struct DonorDonationRow: View {
    let donation: BookingHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(donation.event.name ?? "Acara tanpa nama")
                        .font(.body).bold()
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(dateRangeText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(weightText)
                    .font(.title2).bold()
                    .foregroundColor(AppColor.primaryCyan)
            }
            Divider()
        }
    }

    private var dateRangeText: String {
        switch (donation.event.startAt, donation.event.endAt) {
        case let (start?, end?):
            "\(Self.dayText(start)) – \(Self.dayText(end))"
        case let (start?, nil):
            Self.dayText(start)
        case let (nil, end?):
            Self.dayText(end)
        case (nil, nil):
            "-"
        }
    }

    private var weightText: String {
        let grams = donation.actualWeightGrams ?? donation.estimatedWeightGrams
        let kg = Double(grams) / 1000
        return String(format: "%.1f kg", kg)
    }

    private static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    DonorDonationHistoryView(
        donations: [
            BookingHistoryItem(
                bookingId: UUID(),
                publicBookingId: "KMP-2026-001",
                status: .recycled,
                estimatedWeightGrams: 2500,
                actualWeightGrams: 2300,
                event: BookingEventSnapshot(
                    id: UUID(),
                    name: "Donasi Pakaian Layak Pakai",
                    status: .completed,
                    startAt: .now,
                    endAt: .now,
                    locationName: "Jakarta Selatan",
                    bannerObjectPath: nil
                ),
                createdAt: .now,
                statusUpdatedAt: .now
            ),
            BookingHistoryItem(
                bookingId: UUID(),
                publicBookingId: "KMP-2026-002",
                status: .recycled,
                estimatedWeightGrams: 1000,
                actualWeightGrams: 1250,
                event: BookingEventSnapshot(
                    id: UUID(),
                    name: "Bersih Lemari, Berbagi Sesama",
                    status: .completed,
                    startAt: .now,
                    endAt: .now,
                    locationName: "Jakarta Pusat",
                    bannerObjectPath: nil
                ),
                createdAt: .now,
                statusUpdatedAt: .now
            ),
        ]
    )
}

#Preview("Riwayat Acara dengan Data") {
    DonorEventHistoryView(
        history: [
            BookingHistoryItem(
                bookingId: UUID(),
                publicBookingId: "KMP-2026-003",
                status: .accepted,
                estimatedWeightGrams: 1500,
                actualWeightGrams: nil,
                event: BookingEventSnapshot(
                    id: UUID(),
                    name: "Tukar Baju, Rawat Bumi",
                    status: .ongoing,
                    startAt: .now,
                    endAt: .now.addingTimeInterval(86400),
                    locationName: "Jakarta Selatan",
                    bannerObjectPath: nil
                ),
                createdAt: .now,
                statusUpdatedAt: .now
            ),
            BookingHistoryItem(
                bookingId: UUID(),
                publicBookingId: "KMP-2026-004",
                status: .recycled,
                estimatedWeightGrams: 2000,
                actualWeightGrams: 1850,
                event: BookingEventSnapshot(
                    id: UUID(),
                    name: "Bersih Lemari, Berbagi Sesama",
                    status: .completed,
                    startAt: .now.addingTimeInterval(-172_800),
                    endAt: .now.addingTimeInterval(-86400),
                    locationName: "Jakarta Pusat",
                    bannerObjectPath: nil
                ),
                createdAt: .now,
                statusUpdatedAt: .now
            ),
        ],
        bannerURL: { _ in nil }
    )
}
