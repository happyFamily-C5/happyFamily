//
//  FormView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import SwiftUI

/// Step 1 of the donation flow. Donor identity is served from the profile
/// and encrypted by the server.
struct FormView: View {
    @Environment(DonationViewModel.self) var donationVM
    @Environment(AppRouter.self) var router
    @State var showPrivacyPolice = false
    @State var leaveProcess = false

    /// Phone uses a number pad, which has no Return key — without an explicit
    /// dismissal that keyboard can never be closed. Tapping anywhere off a
    /// field clears focus, and the keyboard toolbar gives a visible way out.
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case phone
    }

    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            eventHeader

            if donationVM.detail == nil, donationVM.isLoadingDetail {
                DonationFormSkeleton()
                    .skeleton(isLoading: true)
            } else if donationVM.detail == nil, let errorMessage = donationVM.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Coba lagi") {
                        Task { await donationVM.retryLoadingEvent() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                formContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .sheet(isPresented: $showPrivacyPolice) {
            PrivacyPolicyView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $leaveProcess) {
            LeaveBookingProses()
                .background(Color.white)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    leaveProcess = true
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
    }

    private var eventHeader: some View {
        HStack(spacing: 16) {
            Group {
                LoadableEventImage(
                    localImage: nil,
                    remoteURL: donationVM.bannerURL(),
                    unavailableLabel: "Banner acara tidak tersedia"
                )
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(donationVM.detail?.event.name ?? "Memuat acara…")
                    .font(.title2).bold()
                Text(donationVM.detail?.event.organizationName ?? "")
                    .font(.headline)
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Personal Information")
                .font(Font.title.bold())

            if donationVM.isProfileComplete {
                VStack(alignment: .leading, spacing: 16) {
                    profileRow(label: "Nama", value: donationVM.displayName)
                    profileRow(label: "Nomor Telepon", value: donationVM.phoneE164)
                    Text("Data diambil dari profilmu dan dikirim terenkripsi oleh server.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Profil belum lengkap. Lengkapi nama dan nomor teleponmu sebelum berdonasi.")
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
        }

        Spacer()

        VStack(spacing: 16) {
            Button("Kenapa kami membutuhkan datamu?") {
                showPrivacyPolice = true
            }
            .font(.subheadline)
            .buttonStyle(.plain)

            if let errorMessage = donationVM.errorMessage, !donationVM.isLoadingDetail {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                if donationVM.canProceedFromPersonalInfo {
                    onNext()
                }
            } label: {
                Text("Lanjut")
                    .padding()
                    .padding(.horizontal, 30)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .background(
                        donationVM.canProceedFromPersonalInfo
                            ? AppColor.primaryCyan
                            : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 30)
                    )
            }
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .font(.body).bold()
        }
        .padding(16)
        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 30))
    }
}

private struct DonationFormSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                SkeletonBlock(cornerRadius: 16)
                    .frame(width: 96, height: 80)
                VStack(alignment: .leading, spacing: 7) {
                    SkeletonBlock(cornerRadius: 5)
                        .frame(width: 170, height: 20)
                    SkeletonBlock(cornerRadius: 5)
                        .frame(width: 120, height: 15)
                }
            }
            SkeletonBlock(cornerRadius: 5)
                .frame(width: 190, height: 25)
            ForEach(0 ..< 2, id: \.self) { _ in
                SkeletonBlock(cornerRadius: 24)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            Spacer(minLength: 80)
            SkeletonBlock(cornerRadius: 24)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    NavigationStack {
        FormView {}
            .environment(AppRouter())
            .environment(DonationViewModel())
    }
}
