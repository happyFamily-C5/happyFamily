//
//  TrackCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

/// Booking row for the tracking list. Facts (status, booking number,
/// drop-off location, banner) come from `account:my_bookings`; nothing is
/// derived from local state.
struct TrackCard: View {
    let booking: DonorBookingListItem
    var bannerURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            banner
                .frame(width: 328, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(statusColor)
                            .font(.system(size: 13))
                        Text(statusText)
                            .foregroundStyle(statusColor)
                            .font(.footnote).bold()
                        Spacer()
                    }

                    Text(booking.event.locationName ?? "Drop Point")
                        .font(.callout).bold()
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                VStack(spacing: 4) {
                    Text("Nomor Booking")
                        .font(.footnote)
                    Text(booking.publicBookingId)
                        .font(.title2).bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var banner: some View {
        LoadableEventImage(
            localImage: nil,
            remoteURL: bannerURL,
            unavailableLabel: "Banner acara tidak tersedia"
        )
    }

    private var statusText: String {
        switch booking.status {
        case .waiting: "Menunggu Drop-off"
        case .accepted: "Diterima"
        case .processed: "Diproses"
        case .recycled: "Selesai"
        case .rejected: "Ditolak"
        case .expired: "Kedaluwarsa"
        case .cancelled: "Dibatalkan"
        }
    }

    private var statusColor: Color {
        switch booking.status {
        case .waiting:
            Color(#colorLiteral(red: 0.95, green: 0.72, blue: 0.28, alpha: 1))
        case .accepted:
            Color(#colorLiteral(red: 0.4410519004, green: 0.8715734482, blue: 0.5325306058, alpha: 1))
        case .processed, .recycled:
            AppColor.primaryCyan
        case .rejected, .expired, .cancelled:
            Color(#colorLiteral(red: 0.9, green: 0.32, blue: 0.34, alpha: 1))
        }
    }
}

#Preview {
    TrackCard(
        booking: DonorBookingListItem(
            bookingId: UUID(),
            publicBookingId: "SS-76329",
            status: .accepted,
            estimatedWeightGrams: 1500,
            actualWeightGrams: nil,
            expiresAt: Date().addingTimeInterval(86400),
            event: .previewFixture,
            canCancel: true,
            createdAt: Date(),
            statusUpdatedAt: nil
        )
    )
    .padding()
}

private extension DonorEventDTO {
    static var previewFixture: DonorEventDTO {
        DonorEventDTO(
            id: UUID(),
            name: "Ecoday | Drop Your Unused Shirt",
            description: nil,
            status: .ongoing,
            startAt: Date(),
            endAt: Date().addingTimeInterval(86400 * 7),
            timezoneName: nil,
            operationalDays: nil,
            opensAtLocal: nil,
            closesAtLocal: nil,
            locationName: "EcoTouch Office",
            locationAddress: nil,
            latitude: nil,
            longitude: nil,
            capacityGrams: 500_000,
            receivedWeightGrams: 0,
            reservedWeightGrams: 0,
            usedWeightGrams: 0,
            maxDonationPerUserGrams: nil,
            bannerObjectPath: nil,
            receiverName: nil,
            receiverPhone: nil,
            receiverAddress: nil,
            organizationName: "EcoTouch Indonesia",
            organizationLogoObjectPath: nil,
            distanceKm: nil,
            criteria: []
        )
    }
}
