import SwiftUI

struct ProfileEventHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let model: AdminHistoryModel

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

                    if let error = model.eventError {
                        HistoryErrorView(message: error) {
                            Task { await model.loadEvents() }
                        }
                        .padding(.horizontal, 20)
                    }

                    if model.isLoadingEvents && model.events.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 170)
                    } else if model.events.isEmpty {
                        ProfileEmptyHistoryView(
                            systemImage: "calendar.badge.exclamationmark",
                            title: "Belum Ada Riwayat Acara",
                            message: "Acara yang selesai akan tampil\ndi halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(model.events) { item in
                                ProfileEventHistoryRow(item: item)
                                    .onAppear {
                                        if item.id == model.events.last?.id, model.hasMoreEvents {
                                            Task { await model.loadMoreEvents() }
                                        }
                                    }
                            }
                            if model.isLoadingMoreEvents {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
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
        .task { await model.loadEvents() }
    }
}

struct ProfileDonationHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let model: AdminHistoryModel
    @State private var trackingBookingId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat\nPendonasi")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)

                    if let error = model.donationError {
                        HistoryErrorView(message: error) {
                            Task { await model.loadDonations() }
                        }
                        .padding(.horizontal, 20)
                    }

                    if model.isLoadingDonations && model.donations.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 170)
                    } else if model.donations.isEmpty {
                        ProfileEmptyHistoryView(
                            systemImage: "list.clipboard",
                            title: "Belum Ada Riwayat Pendonasi",
                            message: "Donatur yang telah memberikan donasi\nakan tampil di halaman ini"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 170)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.donations) { item in
                                ProfileDonationHistoryRow(
                                    item: item,
                                    isSubmitting: trackingBookingId == item.bookingId
                                ) { nextStatus in
                                    track(item.bookingId, to: nextStatus)
                                }

                                Divider()
                            }
                            if model.isLoadingMoreDonations {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
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
        .task { await model.loadDonations() }
    }

    private func track(_ bookingId: UUID, to status: BookingStatusCode) {
        guard trackingBookingId == nil else { return }
        trackingBookingId = bookingId
        Task {
            await model.advanceTracking(bookingId: bookingId, status: status)
            trackingBookingId = nil
        }
    }
}

private struct ProfileEventHistoryRow: View {
    let item: BookingHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            Image("DummyImageBanner")
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.event.name ?? "Acara tanpa nama")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(Self.dateText(from: item.createdAt))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Text(Self.statusLabel(item.event.status))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
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

    private static func statusLabel(_ status: EventStatusCode?) -> String {
        switch status {
        case .draft: "Draf"
        case .upcoming: "Akan Datang"
        case .ongoing: "Berlangsung"
        case .completed: "Selesai"
        case .closed: "Ditutup"
        case .cancelled: "Dibatalkan"
        case nil: "-"
        }
    }
}

private struct ProfileDonationHistoryRow: View {
    let item: BookingHistoryItem
    let isSubmitting: Bool
    let onTrack: (BookingStatusCode) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.event.name ?? item.publicBookingId)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Text(item.publicBookingId)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(Self.relativeText(from: item.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(Self.weightText(grams: item.actualWeightGrams ?? item.estimatedWeightGrams))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color("3-DarkSoftCyan"))

                if let next = Self.nextTrackingStatus(for: item.status) {
                    Button {
                        onTrack(next)
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(next == .processed ? "Tandai Diproses" : "Tandai Didaur Ulang")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color("3-DarkSoftCyan"), in: Capsule())
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private static func nextTrackingStatus(for status: BookingStatusCode) -> BookingStatusCode? {
        switch status {
        case .accepted: .processed
        case .processed: .recycled
        default: nil
        }
    }

    private static func weightText(grams: Int64) -> String {
        String(format: "%.1f kg", Double(grams) / 1000)
    }

    private static func relativeText(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct HistoryErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Coba lagi", action: onRetry)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileEmptyHistoryView: View {
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
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
