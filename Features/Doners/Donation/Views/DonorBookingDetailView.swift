//
//  DonorBookingDetailView.swift
//  happyFamily
//
//  Created by EcoTouch on 09/09/26.
//

import SwiftUI

/// Typed `account:booking_detail` screen: booking facts, server timeline,
/// the QR label (token stored in the Keychain only), and idempotent cancel.
struct DonorBookingDetailView: View {
    let bookingId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State private var model = MyBookingsModel(
        accountClient: BackendDependencies.accountClientOrDefault()
    )
    @State private var showCancelConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Detail Booking")
                        .font(.system(size: 26, weight: .bold))

                    if model.isLoadingDetail, model.detail == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 120)
                    } else if let errorMessage = model.detailError, model.detail == nil {
                        VStack(spacing: 12) {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Coba lagi") {
                                Task { await model.loadDetail(bookingId: bookingId) }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                    } else if let detail = model.detail {
                        detailContent(detail)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .task { await model.loadDetail(bookingId: bookingId) }
        .alert(
            "Batalkan booking?",
            isPresented: $showCancelConfirmation
        ) {
            Button("Batalkan Booking", role: .destructive) {
                Task { await model.cancel(bookingId: bookingId) }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Booking yang dibatalkan tidak dapat dikembalikan.")
        }
        .alert(
            "Pembatalan gagal",
            isPresented: Binding(
                get: { model.cancelError != nil },
                set: {
                    if !$0 {
                        model.cancelError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.cancelError ?? "")
        }
    }

    private func detailContent(_ detail: DonorBookingDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(detail.event.name)
                    .font(.title3).bold()
                Text(detail.publicBookingId)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("Berlaku sampai \(Self.dateText(detail.expiresAt))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                statusChip(detail.status)
                Text(Self.weightText(grams: detail.actualWeightGrams ?? detail.estimatedWeightGrams))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color("3-DarkSoftCyan"))
                Spacer()
            }

            if let qrToken = detail.qrToken {
                VStack(spacing: 10) {
                    Image(uiImage: generateQRCode(from: qrToken))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                    Text("Tunjukkan QR ini saat drop-off")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline")
                    .font(.headline)
                ForEach(detail.timeline) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(AppColor.primaryCyan)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.timelineTitle(entry))
                                .font(.system(size: 14, weight: .semibold))
                            Text(Self.dateText(entry.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(entry.actorType == "donor" ? "Donatur" : "Pengelola")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if detail.canCancel {
                Button {
                    showCancelConfirmation = true
                } label: {
                    HStack {
                        if model.isCancelling {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Batalkan Booking")
                                .font(.body).bold()
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 30))
                }
                .disabled(model.isCancelling)
            }
        }
    }

    private func statusChip(_ status: BookingStatusCode) -> some View {
        Text(Self.statusLabel(status))
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.15), in: Capsule())
    }

    private static func timelineTitle(_ entry: DonorBookingTimelineEntry) -> String {
        switch entry.status {
        case .waiting: "Booking dibuat"
        case .accepted: "Diterima di drop-point"
        case .processed: "Sedang diproses"
        case .recycled: "Selesai didaur ulang"
        case .rejected: "Ditolak"
        case .expired: "Kedaluwarsa"
        case .cancelled: "Dibatalkan"
        }
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func dateText(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        DonorBookingDetailView(bookingId: UUID())
    }
}
