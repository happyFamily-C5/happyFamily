import SwiftUI

struct RegisterAccountView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    
    var onRegisterTapped: (RegisterAccountDraft) -> Void
    var onAppleRegisterTapped: (RegisterAccountDraft) -> Void
    var onLoginTapped: () -> Void
    
    private var isRegisterFormInvalid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                            placeholder: "Masukkan nama",
                            text: $name,
                            textContentType: .name
                        )
                        
                        RegisterInputField(
                            label: "Email",
                            placeholder: "Masukkan email",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        
                        RegisterSecureInputField(
                            label: "Kata Sandi",
                            placeholder: "Masukkan kata sandi",
                            text: $password
                        )
                    }
                    
                    Spacer().frame(height: 52)
                    
                    LoginAuthPrimaryButton(title: "Daftar", isDisabled: isRegisterFormInvalid) {
                        onRegisterTapped(accountDraft)
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
                                .foregroundColor(.secondary)
                            
                            Text("Masuk sekarang!")
                                .foregroundColor(.primary)
                                .underline()
                        }
                        .font(.system(size: 13, weight: .medium))
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
            email: email,
            password: password
        )
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
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(27)
        }
    }
}

private struct RegisterSecureInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            SecureField(placeholder, text: $text)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(27)
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
