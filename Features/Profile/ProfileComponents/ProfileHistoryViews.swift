import SwiftUI

struct ProfileEventHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let model: AdminHistoryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat Acara")
                        .font(.largeTitle).bold()
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)

                    if let error = model.eventError {
                        HistoryErrorView(message: error) {
                            Task { await model.loadEvents() }
                        }
                        .padding(.horizontal, 20)
                    }

                    if model.isLoadingEvents, model.events.isEmpty {
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
                        VStack(spacing: 24) {
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button{
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .task { await model.loadEvents() }
    }
}

struct ProfileDonationHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let model: AdminHistoryModel
    @State private var trackingBookingId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Riwayat\nPendonasi")
                        .font(.largeTitle).bold()
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)

                    if let error = model.donationError {
                        HistoryErrorView(message: error) {
                            Task { await model.loadDonations() }
                        }
                        .padding(.horizontal, 20)
                    }

                    if model.isLoadingDonations, model.donations.isEmpty {
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button{
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .task { await model.loadDonations() }
    }

    private func track(_ bookingId: UUID, to status: BookingStatusCode) {
        guard trackingBookingId == nil else { return }
        trackingBookingId = bookingId
        Task {
            _ = await model.advanceTracking(bookingId: bookingId, status: status)
            trackingBookingId = nil
        }
    }
}

private struct ProfileEventHistoryRow: View {
    let item: BookingHistoryItem

    var body: some View {
        HStack(spacing: 16) {
            Image("DummyImageBanner")
                .resizable()
                .scaledToFill()
                .frame(width: 106, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.event.name ?? "Acara tanpa nama")
                    .font(.title3).bold()
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(Self.dateRangeText(for: item.event))
                    .font(.footnote).bold()
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
    
    private static func dateRangeText(for event: BookingEventSnapshot) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM"

        guard let start = event.startAt,
              let end = event.endAt else {
            return "-"
        }

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.event.name ?? item.publicBookingId)
                    .font(.body).bold()
                    .foregroundColor(.primary)

                Text(Self.relativeText(from: item.createdAt))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(Self.weightText(grams: item.actualWeightGrams ?? item.estimatedWeightGrams))
                    .font(.title2).bold()
                    .foregroundColor(Color("3-DarkSoftCyan"))

//                if let next = Self.nextTrackingStatus(for: item.status) {
//                    Button {
//                        onTrack(next)
//                    } label: {
//                        if isSubmitting {
//                            ProgressView()
//                                .controlSize(.small)
//                        } else {
//                            Text(next == .processed ? "Tandai Diproses" : "Tandai Didaur Ulang")
//                                .font(.system(size: 11, weight: .semibold))
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 10)
//                                .padding(.vertical, 5)
//                                .background(Color("3-DarkSoftCyan"), in: Capsule())
//                        }
//                    }
//                    .disabled(isSubmitting)
//                }
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
        formatter.unitsStyle = .full

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

struct ProfileEmptyHistoryView: View {
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


#Preview {
//    ProfileEventHistoryView(
//        model: AdminHistoryModel(
//            previewEvents: ProfileHistoryBookingDummyData.events
//        )
//    )
    
    ProfileDonationHistoryView(
            model: AdminHistoryModel(
                previewDonations: ProfileDonationHistoryDummyData.donations
            )
        )
}
