import SwiftUI
import PhotosUI

struct DonorProfileCompletionView: View {
    @State private var displayName: String
    @State private var phoneE164: String
    @State private var address = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var avatarObjectPath: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let profile: AccountProfileData
    let onComplete: (AccountProfileUpdate) async throws -> Void

    init(
        profile: AccountProfileData,
        onComplete: @escaping (AccountProfileUpdate) async throws -> Void
    ) {
        _displayName = State(initialValue: profile.displayName)
        _phoneE164 = State(initialValue: profile.phoneE164 ?? "")
        _address = State(initialValue: profile.address ?? "")
        _avatarObjectPath = State(initialValue: profile.avatarObjectPath ?? "")
        self.profile = profile
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 32)
            Text("Lengkapi Profil")
                .font(.title.bold())
            Text("Nama dan nomor WhatsApp diperlukan sebelum membuat booking.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                avatarPreview
                VStack(alignment: .leading, spacing: 6) {
                    Text("Foto Profil (opsional)")
                        .font(.subheadline).bold()
                    let pickerLabel = avatarData == nil ? "Pilih Foto" : "Ganti Foto"
                    PhotosPicker(
                        selection: $avatarItem,
                        matching: .images
                    ) {
                        Text(pickerLabel)
                            .font(.footnote).bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColor.primaryCyan, in: Capsule())
                    }
                }
            }

            TextField("Nama", text: $displayName)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)
            TextField("Nomor WhatsApp, contoh +628123456789", text: $phoneE164)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .textFieldStyle(.roundedBorder)
            TextField("Alamat (opsional)", text: $address, axis: .vertical)
                .lineLimit(2 ... 4)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }

            Spacer()
            Button(isSubmitting ? "Menyimpan…" : "Simpan dan lanjutkan") {
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isSubmitting
                    || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || phoneE164.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .padding(24)
        .onChange(of: avatarItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    avatarData = data
                }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        Group {
            if let avatarData, let image = UIImage(data: avatarData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.gray.opacity(0.4))
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            // The avatar object is uploaded by the donor directly to the
            // private bucket; an untouched path is preserved so the update
            // never releases an existing avatar.
            var resolvedAvatarPath = avatarObjectPath
            if let avatarData {
                let mediaClient = try BackendDependencies.storageMediaClient()
                resolvedAvatarPath = try await mediaClient.uploadProfileAvatar(
                    data: avatarData,
                    userId: profile.id
                )
            }
            try await onComplete(AccountProfileUpdate(
                displayName: displayName,
                phoneE164: phoneE164,
                address: address,
                locationLabel: "",
                latitude: nil,
                longitude: nil,
                avatarObjectPath: resolvedAvatarPath
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
