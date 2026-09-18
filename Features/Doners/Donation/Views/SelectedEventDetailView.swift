//
//  SelectedEventDetailView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import MapKit
import SwiftUI

/// Donor event detail backed by `account:event_detail`: real event data,
/// donor availability, and the CTA that seeds the donation flow.
struct SelectedEventDetailView: View {
    let model: DonorEventDetailModel

    @Environment(AppRouter.self) var router
    @Environment(DonationViewModel.self) var donationVM
    @State private var isStartingFlow = false
    @State private var showPrivacyPolice = false
    @State private var openDonationFlowAfterConsent = false
    @State private var showRequiredProfile = false
    @State private var shouldResumeDonationAfterProfileSave = false

    var body: some View {
        VStack {
            ScrollView(showsIndicators: false) {
                if let detail = model.detail {
                    content(detail)
                } else if model.isLoading {
                    SelectedEventDetailSkeleton()
                        .skeleton(isLoading: true)
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
        .fullScreenCover(isPresented: $showRequiredProfile, onDismiss: resumeDonationAfterProfileSave) {
            DonorProfileEditView(profile: router.donorProfile, mode: .donationRequired) { updated in
                guard let onSaveProfile = router.onSaveDonorProfile else {
                    throw BackendError.configuration("penyimpanan profil donor")
                }
                try await onSaveProfile(updated)
                shouldResumeDonationAfterProfileSave = true
            }
        }
    }

    @ViewBuilder
    private func content(_ detail: DonorEventDetail) -> some View {
        let event = detail.event
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                // MARK: - Banner

                Group {
                    LoadableEventImage(
                        localImage: nil,
                        remoteURL: model.bannerURL(),
                        unavailableLabel: "Banner acara tidak tersedia"
                    )
                }
                .frame(width: 330, height: 330)
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
                    Text(DonorEventScheduleFormatter.dateRangeText(event))
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
                guard ProfileCompletionPolicy.canDonate(router.donorProfile) else {
                    showRequiredProfile = true
                    return
                }
                Task { await beginDonation(eventId: detail.event.id) }
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

    private func beginDonation(eventId: UUID) async {
        guard !isStartingFlow else { return }
        isStartingFlow = true
        await donationVM.start(eventId: eventId)
        isStartingFlow = false

        guard donationVM.isProfileComplete else {
            showRequiredProfile = true
            return
        }
        showPrivacyPolice = true
    }

    private func resumeDonationAfterProfileSave() {
        guard shouldResumeDonationAfterProfileSave,
              let eventId = model.detail?.event.id
        else { return }
        shouldResumeDonationAfterProfileSave = false
        Task { await beginDonation(eventId: eventId) }
    }
}

private struct SelectedEventDetailSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            SkeletonBlock(cornerRadius: 16)
                .frame(width: 330, height: 330)
            SkeletonBlock(cornerRadius: 5)
                .frame(width: 230, height: 28)
            SkeletonBlock(cornerRadius: 5)
                .frame(width: 150, height: 18)
            SkeletonBlock(cornerRadius: 5)
                .frame(width: 170, height: 16)
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(cornerRadius: 5)
                    .frame(width: 130, height: 20)
                SkeletonBlock(cornerRadius: 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                SkeletonBlock(cornerRadius: 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
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
