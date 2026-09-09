import AuthenticationServices
import SwiftUI

private enum LoginField {
    case email
    case password
}

/// Organizer sign-in screen driven by the real Supabase auth
/// (`AuthViewModel`/`AuthSession`). Sign in with Apple follows the API
/// contract: a hashed nonce goes to Apple, the raw nonce goes to Supabase.
struct LoginWelcomeView: View {
    @State private var model: AuthViewModel
    @State private var appleNonce: AppleSignInSupport.Nonce?
    @FocusState private var focusedField: LoginField?

    var onAuthenticated: () -> Void
    var onRegisterTapped: () -> Void

    init(
        authSession: (any AuthSession)? = BackendDependencies.authSessionOrDefault(),
        onAuthenticated: @escaping () -> Void,
        onRegisterTapped: @escaping () -> Void
    ) {
        _model = State(initialValue: AuthViewModel(authSession: authSession))
        self.onAuthenticated = onAuthenticated
        self.onRegisterTapped = onRegisterTapped
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 76)

                AppLogoHeaderView(imageSize: 82)

                Spacer().frame(height: 28)

                Text("Selamat Datang Kembali")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 28)

                VStack(spacing: 16) {
                    LoginInputField(
                        label: "Email",
                        placeholder: "Masukkan email",
                        text: $model.email,
                        keyboardType: .emailAddress,
                        submitLabel: .next,
                        focus: $focusedField,
                        field: .email
                    ) {
                        focusedField = .password
                    }

                    LoginSecureInputField(
                        label: "Password",
                        placeholder: "Masukkan password",
                        text: $model.password,
                        focus: $focusedField,
                        field: .password
                    ) {
                        Task { await submit() }
                    }
                }

                if let error = model.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.top, 16)
                }

                Spacer().frame(height: 52)

                LoginAuthPrimaryButton(
                    title: model.isSubmitting ? "Memproses…" : "Masuk",
                    isDisabled: !model.isSubmitEnabled
                ) {
                    Task { await submit() }
                }

                Spacer().frame(height: 24)

                LoginDividerLabel(text: "atau")

                Spacer().frame(height: 18)

                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        // Fresh nonce per request; Apple verifies the hash,
                        // Supabase verifies the raw value.
                        let nonce = AppleSignInSupport.newNonce()
                        appleNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = nonce.hashed
                    },
                    onCompletion: { handleAppleCompletion($0) }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: 375)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .disabled(model.isSubmitting)
                .opacity(model.isSubmitting ? 0.6 : 1)
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 22)

                Button(action: onRegisterTapped) {
                    HStack(spacing: 4) {
                        Text("Belum punya akun?")
                            .foregroundColor(.secondary)

                        Text("Daftar sekarang!")
                            .foregroundColor(.primary)
                            .underline()
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(model.isSubmitting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private func submit() async {
        focusedField = nil
        let authenticated = await model.submit()
        if authenticated {
            onAuthenticated()
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce else {
                model.errorMessage = "Sign in with Apple tidak lengkap. Coba lagi."
                return
            }
            Task {
                if await model.submitApple(idToken: idToken, nonce: nonce.raw) {
                    onAuthenticated()
                }
            }
        case .failure(let error):
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
            model.errorMessage = "Sign in with Apple gagal. Coba lagi atau gunakan email."
        }
    }
}

private struct LoginInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .go
    var focus: FocusState<LoginField?>.Binding
    let field: LoginField
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .submitLabel(submitLabel)
                .focused(focus, equals: field)
                .onSubmit(onSubmit)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(#colorLiteral(red: 0.9214347005, green: 0.9214347005, blue: 0.9214347005, alpha: 1)))
                .cornerRadius(27)
        }
    }
}

private struct LoginSecureInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<LoginField?>.Binding
    let field: LoginField
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .submitLabel(.go)
                .focused(focus, equals: field)
                .onSubmit(onSubmit)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(#colorLiteral(red: 0.9214347005, green: 0.9214347005, blue: 0.9214347005, alpha: 1)))
                .cornerRadius(27)
        }
    }
}

struct LoginDividerLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }
}

#Preview {
    LoginWelcomeView(
        authSession: nil,
        onAuthenticated: {},
        onRegisterTapped: {}
    )
}
