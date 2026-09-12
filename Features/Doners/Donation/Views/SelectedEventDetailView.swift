//
//  EventDetailView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import SwiftUI
import MapKit

/// Donor event detail backed by `account:event_detail`: real event data,
/// donor availability, and the CTA that seeds the donation flow.
struct SelectedEventDetailView: View {
    let model: DonorEventDetailModel

    @Environment(AppRouter.self) var router
    @Environment(DonationViewModel.self) var donationVM
    @State private var isStartingFlow = false
    @State private var showPrivacyPolice = false
    @State private var openDonationFlowAfterConsent = false

    var body: some View {
        VStack {
            ScrollView(showsIndicators: false) {
                if let detail = model.detail {
                    content(detail)
                } else if model.isLoading {
                    VStack {
                        ProgressView("Memuat acara…")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else if let errorMessage = model.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Coba lagi") {
                            Task { await model.load() }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }

            ctaButton
        }
        .padding(.horizontal, 20)
        .task {
            if model.detail == nil, !model.isLoading {
                await model.load()
            }
        }
        .sheet(isPresented: $showPrivacyPolice, onDismiss: openDonationFlowIfAccepted) {
            PrivacyPoliceInstructionPage {
                donationVM.agreedToTerms = true
                openDonationFlowAfterConsent = true
                showPrivacyPolice = false
            }
            .background(Color.white)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func content(_ detail: DonorEventDetail) -> some View {
        let event = detail.event
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                // MARK: - Banner
                Group {
                    if let bannerURL = model.bannerURL() {
                        AsyncImage(url: bannerURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image("Image 2").resizable().scaledToFill()
                        }
                    } else {
                        Image("Image 2")
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 330)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // MARK: - Title
                VStack {
                    Text(event.name)
                        .font(.title).bold()
                        .multilineTextAlignment(.center)
                    Text(event.organizationName ?? "")
                        .font(.headline).bold()
                }

                // MARK: - Date Time
                VStack(spacing: 4) {
                    Text(Self.dateRangeText(event))
                        .font(.callout).bold()
                    if let timeInfo = model.timeInfoText {
                        Text(timeInfo)
                            .font(.callout).bold()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Donation Capacity
                if let maxKg = event.maxDonationPerUserGrams.map({ Double($0) / 1000 }) {
                    MaxDonationCard(maxCapacity: maxKg)
                }

                // MARK: - Kriteria Donasi
                Text("Kriteria Donasi")
                    .font(.body).bold()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(event.criteria, id: \.self) { criterion in
                            Text(criterion.uiLabel)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 16)
                                .font(.footnote).bold()
                                .background(
                                    Color(#colorLiteral(red: 0.9499571919, green: 0.9500558972, blue: 0.953115046, alpha: 1)),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                        }
                    }
                }

                // MARK: Lokasi
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lokasi")
                            .font(.body).bold()
                        Divider()
                    }

                    LocationDisclosureCard(
                        name: event.locationName ?? "-",
                        address: event.locationAddress ?? "-",
                        distance: event.distanceKm ?? 0
                    )

                    if let latitude = event.latitude, let longitude = event.longitude {
                        MapView(
                            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                            locationName: event.locationName ?? "Lokasi acara"
                        )
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                }

                // MARK: - Deskripsi
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deskripsi Acara")
                            .font(.body).bold()
                        Divider()
                    }

                    Text(event.description?.isEmpty == false ? event.description! : "Belum ada deskripsi acara.")
                        .font(.callout)
                }
            }

            Spacer()
        }
    }

    private var bookable: Bool {
        model.detail?.availability.bookable == true
    }

    private var ctaButton: some View {
        VStack(spacing: 6) {
            Button {
                guard let detail = model.detail, bookable, !isStartingFlow else { return }
                isStartingFlow = true
                Task {
                    await donationVM.start(eventId: detail.event.id)
                    isStartingFlow = false
                    showPrivacyPolice = true
                }
            } label: {
                Text(isStartingFlow ? "Menyiapkan…" : "Donasikan Pakaian")
                    .foregroundStyle(Color.white)
                    .font(.body).bold()
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        bookable ? AppColor.primaryCyan : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 60)
                    )
            }
            .disabled(!bookable || isStartingFlow)

            if model.detail?.alreadyBooked == true {
                Text("Kamu sudah memiliki booking aktif di acara ini.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if model.detail?.availability.availableWeightGrams != nil, !bookable {
                Text("Kapasitas tersisa tidak cukup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func openDonationFlowIfAccepted() {
        guard openDonationFlowAfterConsent else { return }
        openDonationFlowAfterConsent = false
        router.push(to: .donationFlow)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static func dateRangeText(_ event: DonorEventDTO) -> String {
        switch (event.startAt, event.endAt) {
        case let (start?, end?):
            "\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))"
        case let (start?, nil):
            dateFormatter.string(from: start)
        case let (nil, end?):
            dateFormatter.string(from: end)
        default:
            "-"
        }
    }
}

#Preview {
    NavigationStack {
        SelectedEventDetailView(
            model: DonorEventDetailModel(
                eventId: UUID(),
                accountClient: nil,
                backendBaseURL: nil
            )
        )
        .environment(AppRouter())
        .environment(DonationViewModel())
    }
}
