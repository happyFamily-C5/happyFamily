//
//  FormView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import SwiftUI

struct FormView: View {
    @Environment(DonationViewModel.self) var donationVM
    @Environment(AppRouter.self) var router
    @State var showNameError = false
    @State var showPhoneError = false
    @State private var showConsentError = false

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

        VStack(alignment: .leading, spacing: 36) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    AsyncImage(url: donationVM.bannerURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            Image("Image 2")
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(donationVM.resolvedEvent?.name ?? "Acara .kumpul")
                            .font(.title).bold()
                        Text(donationVM.resolvedEvent?.receiverName ?? "Penerima donasi")
                            .font(.headline)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Personal Information")
                        .font(Font.title.bold())
                    Divider()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.body)
                    TextField("Enter your name", text: $donationVM.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .phone }
                        .padding(20)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 30))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(
                                    showNameError ? Color.red : Color.red.opacity(0.0)
                                )
                        )
                    if showNameError {
                        Text("*Name is required")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.body)
                    TextField("Active phone number", text: $donationVM.phone)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .phone)
                        .padding(20)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 30))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(
                                    showPhoneError ? Color.red : Color.red.opacity(0.0)
                                )
                        )
                    if showPhoneError {
                        Text("*Phone number is required")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Saya menyetujui syarat layanan dan kebijakan privasi.", isOn: $donationVM.agreedToTerms)
                        .toggleStyle(.switch)

                    if let legal = donationVM.legal {
                        HStack(spacing: 16) {
                            Link("Syarat Layanan", destination: legal.termsURL)
                            Link("Kebijakan Privasi", destination: legal.privacyURL)
                        }
                        .font(.footnote)
                    }

                    if showConsentError {
                        Text("*Persetujuan diperlukan untuk membuat booking")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            Spacer()
            Button {
                focusedField = nil
                if donationVM.name.isEmpty {
                    showNameError = true
                } else {
                    showNameError = false
                }
                if donationVM.phone.isEmpty {
                    showPhoneError = true
                } else {
                    showPhoneError = false
                }
                showConsentError = !donationVM.agreedToTerms
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
                        AppColor.primaryCyan,
                        in: RoundedRectangle(cornerRadius: 30)
                    )
            }
        }
        // Fill the step's area so the empty space around the fields is tappable,
        // then treat a tap on that space as "dismiss the keyboard".
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .onChange(of: donationVM.name) { _, newValue in
            if !newValue.isEmpty {
                showNameError = false
            }
        }.onChange(of: donationVM.phone) { _, newValue in
            if !newValue.isEmpty {
                showPhoneError = false
            }
        }.onChange(of: donationVM.agreedToTerms) { _, agreed in
            if agreed {
                showConsentError = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        FormView {}
            .environment(AppRouter())
            .environment(DonationViewModel())
    }
}
