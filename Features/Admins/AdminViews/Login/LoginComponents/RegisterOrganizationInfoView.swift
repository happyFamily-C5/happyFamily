import SwiftUI

struct RegisterOrganizationInfoView: View {
    @State private var officeName = ""
    @State private var officeAddress = ""
    @State private var officeContact = ""
    
    var initialEmail: String
    var onCreateAccountTapped: (AdminProfile) -> Void
    var onBackTapped: () -> Void
    
    private var isFormInvalid: Bool {
        officeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        officeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        officeContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            LoginAnimatedGreenGradientBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onBackTapped) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 38, height: 38)
                            .background(Color(.systemBackground).opacity(0.86))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 12)
                    
                    Spacer().frame(height: 42)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lengkapi Informasi Kantor")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Informasi ini akan ditampilkan pada halaman profil.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer().frame(height: 30)
                    
                    VStack(spacing: 16) {
                        OrganizationInputField(
                            label: "Nama Kantor",
                            placeholder: "Masukkan nama kantor",
                            text: $officeName
                        )
                        
                        OrganizationInputField(
                            label: "Alamat Kantor",
                            placeholder: "Masukkan alamat kantor",
                            text: $officeAddress,
                            minHeight: 112,
                            isMultiline: true
                        )
                        
                        OrganizationInputField(
                            label: "Kontak Kantor",
                            placeholder: "Masukkan kontak kantor",
                            text: $officeContact,
                            keyboardType: .phonePad
                        )
                    }
                    
                    Spacer().frame(height: 52)
                    
                    LoginAuthPrimaryButton(title: "Buat Akun", isDisabled: isFormInvalid) {
                        onCreateAccountTapped(
                            AdminProfile(
                                companyName: officeName,
                                companyAddress: officeAddress,
                                phoneNumber: officeContact,
                                email: initialEmail,
                                imageData: nil
                            )
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct OrganizationInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 54
    var isMultiline = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Group {
                if isMultiline {
                    TextEditor(text: $text)
                        .font(.system(size: 15, weight: .medium))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: minHeight)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(placeholder)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 16)
                        .frame(height: minHeight)
                }
            }
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(27)
        }
    }
}

#Preview {
    RegisterOrganizationInfoView(
        initialEmail: "hello@ecotouch.id",
        onCreateAccountTapped: { _ in },
        onBackTapped: {}
    )
}
