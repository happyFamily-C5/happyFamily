//
//  FormView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import SwiftUI

/// Step 1 of the donation flow. Donor identity is served from the profile
/// (the server encrypts it) and the legal versions come from the event
/// detail, so this step collects the shipping method and the consent only.
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
        @Bindable var donationVM = donationVM

        VStack(alignment: .leading, spacing: 32) {
            eventHeader

            if donationVM.detail == nil && donationVM.isLoadingDetail {
                VStack {
                    ProgressView("Memuat acara…")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Button{
                    leaveProcess = true
                }label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
    }

    private var eventHeader: some View {
        HStack(spacing: 16) {
            Group {
                if let bannerURL = donationVM.bannerURL() {
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
        @Bindable var donationVM = donationVM

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

            VStack(alignment: .leading, spacing: 12) {
                Text("Metode Pengantaran")
                    .font(.headline)
                ForEach(ShippingMethod.allCases) { method in
                    DropMethodCard(
                        method: method.rawValue,
                        description: method.description,
                        isSelected: donationVM.selectedShippingMethod == method
                    ) {
                        donationVM.selectedShippingMethod = method
                    }
                }
            }

            Toggle(isOn: $donationVM.agreedToTerms) {
                Text("Saya menyetujui Syarat & Ketentuan serta Kebijakan Privasi")
                    .font(.footnote)
            }
        }

        Spacer()

        VStack(spacing: 16) {
            Text("Kenapa kami membutuhkan datamu ?")
                .font(.subheadline)
                .onTapGesture {
                    showPrivacyPolice = true
                }

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

#Preview {
    NavigationStack {
        FormView {}
            .environment(AppRouter())
            .environment(DonationViewModel())
    }
}
