import SwiftUI

struct LoginWelcomeView: View {
    @State private var email = ""
    @State private var password = ""
    
    var onLoginTapped: () -> Void
    var onAppleLoginTapped: () -> Void
    var onRegisterTapped: () -> Void
    
    private var isLoginFormInvalid: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
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
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        LoginSecureInputField(
                            label: "Password",
                            placeholder: "Masukkan password",
                            text: $password
                        )
                    }
                    
                    Spacer().frame(height: 52)
                    
                    LoginAuthPrimaryButton(title: "Masuk", isDisabled: isLoginFormInvalid) {
                        onLoginTapped()
                    }
                    
                    Spacer().frame(height: 24)
                    
                    LoginDividerLabel(text: "atau")
                    
                    Spacer().frame(height: 18)
                    
                    SocialAuthButton(title: "Masuk dengan Apple") {
                        onAppleLoginTapped()
                    }
                    
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
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            
        }
    }
}

private struct LoginInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(#colorLiteral(red: 0.9214347005, green: 0.9214347005, blue: 0.9214347005, alpha: 1)))
                .cornerRadius(27)
        }
    }
}

private struct LoginDividerLabel: View {
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
        onLoginTapped: {},
        onAppleLoginTapped: {},
        onRegisterTapped: {}
    )
}
