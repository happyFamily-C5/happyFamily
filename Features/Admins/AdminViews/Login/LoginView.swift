//
//  LoginView.swift
//  happyFamily
//

import SwiftUI

/// Organizer sign-in gate. Visual language follows the dashboard: pill
/// text fields on systemGray6, PrimaryButton, and the brand illustration.
struct LoginView: View {
    @State private var model: AuthViewModel
    @State private var isPasswordVisible: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var onAuthenticated: () -> Void

    init(
        authSession: (any AuthSession)? = BackendDependencies.authSessionOrDefault(),
        onAuthenticated: @escaping () -> Void
    ) {
        _model = State(initialValue: AuthViewModel(authSession: authSession))
        self.onAuthenticated = onAuthenticated
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 24)

                    Image("EmptyRecycleImage")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 140)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 8) {
                        Text(model.isSignUpMode
                            ? "Buat Akun Baru"
                            : "Selamat Datang Kembali")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        Text("Kelola event pengumpulan limbah tekstilmu di .kumpul")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 16) {
                        fieldSection(
                            title: "Email",
                            prompt: (model.email.isEmpty || model.isEmailValid) ? nil : model.emailPrompt
                        ) {
                            TextField("nama@email.com", text: $model.email)
                                .font(.system(size: 15))
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }

                        fieldSection(
                            title: "Kata Sandi",
                            prompt: model.passwordPrompt
                        ) {
                            HStack(spacing: 8) {
                                if isPasswordVisible {
                                    TextField("Kata sandi", text: $model.password)
                                        .font(.system(size: 15))
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit { Task { await submit() } }
                                } else {
                                    SecureField("Kata sandi", text: $model.password)
                                        .font(.system(size: 15))
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit { Task { await submit() } }
                                }

                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    if let info = model.infoMessage {
                        Label(info, systemImage: "envelope.badge")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color("2-BoldDarkSoftCyan"))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color("6-VeryLightSoftCyan"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    PrimaryButton(
                        title: model.isSubmitting ? "Memproses…" : model.primaryButtonTitle,
                        action: { Task { await submit() } }
                    )
                    .disabled(model.isSubmitting)
                    .opacity(model.isSubmitting ? 0.6 : 1)

                    Button {
                        model.errorMessage = nil
                        model.infoMessage = nil
                        model.isSignUpMode.toggle()
                    } label: {
                        Text(model.modeToggleText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("2-BoldDarkSoftCyan"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(model.isSubmitting)

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private func fieldSection<Content: View>(
        title: String,
        prompt: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 30))

            if let prompt {
                Text(prompt)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    private func submit() async {
        focusedField = nil
        let authenticated = await model.submit()
        if authenticated {
            onAuthenticated()
        }
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    NavigationStack {
        LoginView(authSession: nil) {
            print("Authenticated!")
        }
    }
}
