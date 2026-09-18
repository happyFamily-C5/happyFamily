//
//  TrackingHistoryView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

/// Donor tracking page: every active booking from `account:my_bookings`.
/// Tapping a card opens the typed `account:booking_detail` screen with the
/// server timeline, QR, and idempotent cancellation.
struct TrackingHistoryView: View {
    @Environment(AppRouter.self) private var router
    @State private var model = MyBookingsModel(
        accountClient: BackendDependencies.accountClientOrDefault()
    )

    var body: some View {
        Group {
            if model.isLoading, model.bookings.isEmpty {
                TrackingHistorySkeleton()
            } else if let errorMessage = model.errorMessage, model.bookings.isEmpty {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Coba lagi") {
                        Task { await model.load() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.bookings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Belum ada booking berjalan.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Buat booking donasi untuk mulai melacak.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(model.bookings) { booking in
                            Button {
                                router.push(to: .bookingDetail(booking.bookingId))
                            } label: {
                                TrackCard(
                                    booking: booking,
                                    bannerURL: model.bannerURL(for: booking)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(
            Color(#colorLiteral(red: 0.9594156146, green: 0.9598115087, blue: 0.9719882607, alpha: 1))
                .ignoresSafeArea()
        )
        .navigationTitle("Lacak Donasi")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}

private struct TrackingHistorySkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 16) {
                        SkeletonBlock(cornerRadius: 16)
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                SkeletonBlock(cornerRadius: 4)
                                    .frame(width: 130, height: 14)
                                SkeletonBlock(cornerRadius: 4)
                                    .frame(width: 110, height: 16)
                            }
                            Spacer()
                            SkeletonBlock(cornerRadius: 4)
                                .frame(width: 80, height: 12)
                        }
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .skeleton(isLoading: true)
        }
    }
}

#Preview {
    NavigationStack {
        TrackingHistoryView()
            .environment(AppRouter())
    }
}
