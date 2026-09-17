import SwiftUI

struct RegisterAccountView: View {
    @State private var name = ""
    @State private var model: AuthViewModel
    
    var onRegisterTapped: (RegisterAccountDraft) -> Void
    var onAppleRegisterTapped: (RegisterAccountDraft) -> Void
    var onLoginTapped: () -> Void
    
    init(
        authSession: (any AuthSession)? = BackendDependencies.authSessionOrDefault(),
        onRegisterTapped: @escaping (RegisterAccountDraft) -> Void,
        onAppleRegisterTapped: @escaping (RegisterAccountDraft) -> Void,
        onLoginTapped: @escaping () -> Void
    ) {
        let model = AuthViewModel(authSession: authSession)
        model.isSignUpMode = true
        _model = State(initialValue: model)
        self.onRegisterTapped = onRegisterTapped
        self.onAppleRegisterTapped = onAppleRegisterTapped
        self.onLoginTapped = onLoginTapped
    }
    
    private var isRegisterFormInvalid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !model.isSubmitEnabled ||
        !model.isEmailValid ||
        !model.isPasswordValid
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 72)
                
                AppLogoHeaderView(imageSize: 82)
                
                Spacer().frame(height: 28)
                
                Text("Buat Akun Baru")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Spacer().frame(height: 28)
                
                VStack(spacing: 16) {
                    RegisterInputField(
                        label: "Nama",
                        placeholder: "John mayer",
                        text: $name,
                        textContentType: .name
                    )
                    
                    RegisterInputField(
                        label: "Email",
                        placeholder: "john@gmail.com",
                        text: $model.email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    
                    RegisterSecureInputField(
                        label: "Kata Sandi",
                        placeholder: "pilih kata sandi",
                        text: $model.password
                    )
                }
                
                Spacer().frame(height: 52)
                
                if let error = model.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.bottom, 16)
                }
                
                LoginAuthPrimaryButton(title: model.isSubmitting ? "Memproses…" : "Daftar", isDisabled: isRegisterFormInvalid) {
                    Task { await submit() }
                }
                
                Spacer().frame(height: 24)
                
                RegisterDividerLabel(text: "atau")
                
                Spacer().frame(height: 18)
                
                SocialAuthButton(title: "Daftar dengan Apple") {
                    onAppleRegisterTapped(accountDraft)
                }
                
                Spacer().frame(height: 22)
                
                Button(action: onLoginTapped) {
                    HStack(spacing: 4) {
                        Text("Sudah punya akun?")
                            .foregroundColor(.primary)
                        
                        Text("Masuk")
                            .foregroundColor(.primary)
                            .underline()
                    }
                    .font(.callout)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var accountDraft: RegisterAccountDraft {
        RegisterAccountDraft(
            name: name,
            email: model.email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: model.password
        )
    }
    
    private func submit() async {
        guard await model.submit() else { return }
        onRegisterTapped(accountDraft)
    }
}

private struct RegisterInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(#colorLiteral(red: 0.9215686275, green: 0.9215686275, blue: 0.9215686275, alpha: 1)))
                .cornerRadius(27)
        }
    }
}

private struct RegisterSecureInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @State var isPasswordVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            ZStack(alignment: .trailing){
                Group{
                    if !isPasswordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(AppColor.fieldBackground)
                .cornerRadius(27)
                
                
                Button(action: {
                    isPasswordVisible.toggle()
                }, label: {
                    Image(systemName: self.isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                })
                .padding(.trailing, 16)
            }
        }
    }
}

private struct RegisterDividerLabel: View {
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
    RegisterAccountView(
        onRegisterTapped: { _ in },
        onAppleRegisterTapped: { _ in },
        onLoginTapped: {}
    )
}
