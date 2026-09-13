//
//  MyBookingsView.swift
//  happyFamily
//
//  Created by EcoTouch on 09/09/26.
//

import SwiftUI

/// Donor booking list from `account:my_bookings`; rows open the typed
/// `account:booking_detail` screen with timeline, QR, and cancellation.
struct MyBookingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State private var model = MyBookingsModel(
        accountClient: BackendDependencies.accountClientOrDefault()
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                onBackTapped: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Pesanan Saya")
                        .font(.system(size: 26, weight: .bold))
                        .padding(.horizontal, 20)

                    if let errorMessage = model.errorMessage, model.bookings.isEmpty {
                        VStack(spacing: 12) {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Coba lagi") {
                                Task { await model.load() }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                    } else if model.isLoading, model.bookings.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 120)
                    } else if model.bookings.isEmpty {
                        Text("Belum ada pesanan donasi.\nBooking yang kamu buat akan tampil di sini.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 120)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(model.bookings) { booking in
                                Button {
                                    router.push(to: .bookingDetail(booking.bookingId))
                                } label: {
                                    bookingRow(booking)
                                }
                                .buttonStyle(.plain)
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
        .task { await model.load() }
    }

    private func bookingRow(_ booking: DonorBookingListItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.event.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(booking.publicBookingId)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Text(Self.statusLabel(booking.status))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15), in: Capsule())

                    Text(Self.weightText(grams: booking.actualWeightGrams ?? booking.estimatedWeightGrams))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color("3-DarkSoftCyan"))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
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
}

#Preview {
    MyBookingsView()
}
