import PhotosUI
import SwiftUI

/// Donor profile editor. Saving is backend-backed: an untouched avatar path
/// is preserved, a picked image is uploaded by the donor to the private
/// `profile-avatars` bucket first, then `account:update_profile` runs once.
@MainActor
struct DonorProfileEditView: View {
    enum Mode: Equatable {
        case edit
        case donationRequired
    }

    @Environment(\.dismiss) private var dismiss

    let profile: DonorProfile
    let mode: Mode
    /// Applies the edit to the backend and the bound profile. Throws when
    /// the upload or the profile update fails; the sheet stays open.
    let onSave: (DonorProfile) async throws -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var draftFullName: String
    @State private var draftPhoneE164: String
    @State private var draftAddress: String
    @State private var draftImageData: Data?
    @State private var isPhotoPickerPresented = false
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isFieldFocused: Bool

    init(
        profile: DonorProfile,
        mode: Mode = .edit,
        onSave: @escaping (DonorProfile) async throws -> Void
    ) {
        self.profile = profile
        self.mode = mode
        self.onSave = onSave
        _draftFullName = State(initialValue: profile.fullName)
        _draftPhoneE164 = State(initialValue: profile.phoneE164)
        _draftAddress = State(initialValue: profile.address)
        _draftImageData = State(initialValue: profile.imageData)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileBackBar(
                showsSave: true,
                isSaveDisabled: isSaving || (mode == .donationRequired && !canSaveDonationProfile),
                onBackTapped: { dismiss() },
                onSaveTapped: { Task { await saveProfile() } }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if mode == .donationRequired {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Lengkapi Profil")
                                .font(.title2.bold())
                            Text("Nama dan nomor WhatsApp diperlukan sebelum berdonasi.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        isPhotoPickerPresented = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            ProfileLogoImage(imageData: draftImageData, size: 88)

                            Image(systemName: "photo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionTitle(title: "Informasi Umum")

                        ProfileTextInput(
                            placeholder: "Nama",
                            text: $draftFullName
                        )
                        .focused($isFieldFocused)

                        ProfileTextInput(
                            placeholder: "Alamat",
                            text: $draftAddress,
                            minHeight: 112,
                            isMultiline: true
                        )
                        .focused($isFieldFocused)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionTitle(title: "Informasi Kontak")
                        ProfileTextInput(
                            placeholder: "Nomor WhatsApp",
                            text: $draftPhoneE164,
                            keyboardType: .phonePad
                        )
                        .focused($isFieldFocused)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Menyimpan…")
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .contentShape(Rectangle())
        .onTapGesture {
            isFieldFocused = false
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedItem,
            matching: .images
        )
        .onChange(of: selectedItem, loadSelectedImage)
        .alert(
            "Simpan profil gagal",
            isPresented: Binding(
                get: { saveError != nil },
                set: {
                    if !$0 {
                        saveError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func saveProfile() async {
        guard !isSaving, mode != .donationRequired || canSaveDonationProfile else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            var updated = profile
            updated.fullName = draftFullName.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.phoneE164 = draftPhoneE164.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.address = draftAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.imageData = draftImageData

            // An untouched path is preserved so the update never releases an
            // existing avatar; a picked image is uploaded first, by the
            // donor, into their own bucket prefix.
            var avatarObjectPath = profile.avatarObjectPath
            if let draftImageData, draftImageData != profile.imageData {
                guard let userId = profile.id else {
                    throw BackendError.configuration("akun donor belum diketahui")
                }
                let mediaClient = try BackendDependencies.storageMediaClient()
                avatarObjectPath = try await mediaClient.uploadProfileAvatar(
                    data: draftImageData,
                    userId: userId
                )
            }
            updated.avatarObjectPath = avatarObjectPath

            try await onSave(updated)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var canSaveDonationProfile: Bool {
        ProfileCompletionPolicy.canDonate(DonorProfile(
            fullName: draftFullName,
            address: draftAddress,
            imageData: draftImageData,
            id: profile.id,
            phoneE164: draftPhoneE164,
            avatarObjectPath: profile.avatarObjectPath
        ))
    }

    private func loadSelectedImage(_ oldItem: PhotosPickerItem?, _ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                await MainActor.run {
                    draftImageData = data
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var profile = DonorProfile.defaultProfile

    DonorProfileEditView(profile: profile) { _ in }
}
