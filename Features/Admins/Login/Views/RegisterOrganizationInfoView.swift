import SwiftUI

struct RegisterOrganizationInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var officeName: String
    @State private var officeAddress: String
    @State private var officeContact: String
    @State private var officeEmail: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let initialProfile: AdminProfile
    private let onSave: (AdminProfile) async throws -> Void

    init(
        profile: AdminProfile,
        onSave: @escaping (AdminProfile) async throws -> Void
    ) {
        initialProfile = profile
        self.onSave = onSave
        _officeName = State(initialValue: profile.companyName)
        _officeAddress = State(initialValue: profile.companyAddress)
        _officeContact = State(initialValue: profile.phoneNumber)
        _officeEmail = State(initialValue: profile.email)
    }

    private var isFormInvalid: Bool {
        officeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            officeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            officeContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            officeEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { dismiss() }) {
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
                    Text("Lengkapi Profil Pengelola")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Nama organisasi, alamat, nomor telepon, dan email diperlukan sebelum membuat event.")
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
                        isMultiline: true
                    )

                    OrganizationInputField(
                        label: "Kontak Kantor",
                        placeholder: "Masukkan kontak kantor",
                        text: $officeContact,
                        keyboardType: .phonePad
                    )

                    OrganizationInputField(
                        label: "Email Kantor",
                        placeholder: "Masukkan email kantor",
                        text: $officeEmail,
                        keyboardType: .emailAddress
                    )
                }

                Spacer().frame(height: 52)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.bottom, 16)
                }

                LoginAuthPrimaryButton(
                    title: isSaving ? "Menyimpan…" : "Simpan dan buat event",
                    isDisabled: isSaving || isFormInvalid
                ) {
                    Task { await save() }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func save() async {
        guard !isSaving, !isFormInvalid else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        var updated = initialProfile
        updated.companyName = officeName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.companyAddress = officeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.phoneNumber = officeContact.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.email = officeEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
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
                        .textInputAutocapitalization(
                            keyboardType == .emailAddress ? .never : .words
                        )
                        .autocorrectionDisabled()
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 16)
                        .frame(height: minHeight)
                }
            }
            .background(Color(#colorLiteral(red: 0.9214347005, green: 0.9214347005, blue: 0.9214347005, alpha: 1)))
            .cornerRadius(27)
        }
    }
}

#Preview {
    RegisterOrganizationInfoView(
        profile: .defaultProfile,
        onSave: { _ in }
    )
}
