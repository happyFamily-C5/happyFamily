import PhotosUI
import SwiftUI
import UIKit

struct DonorProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var profile: DonorProfile
    var onLogout: () -> Void = {}
    var onDeleteAccount: (() async throws -> Void)?
    @State private var isShowingEditProfile = false
    @State private var isShowingEventHistory = false
    @State private var isShowingDonationHistory = false
    @State private var isShowingLogoutConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var history = DonorHistoryModel(
        accountClient: BackendDependencies.accountClientOrDefault()
    )

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                ProfileTopBar(
                    onCloseTapped: { dismiss() }
                )

                VStack(alignment: .leading, spacing: 24) {
                    ProfileHeaderCard(
                        imageData: profile.imageData,
                        name: profile.fullName,
                        address: profile.address,
                        namePlaceholder: "Nama Anda",
                        addressPlaceholder: "Alamat Anda",
                        onTap: { isShowingEditProfile = true }
                    )

                    List {
                        Section(
                            header: Text("Aktifitas Terbaru")
                                .font(.title2)
                                .bold()
                                .foregroundStyle(Color.black)
                        ) {
                            Button {
                                isShowingEventHistory = true
                            } label: {
                                HStack {
                                    Text("Riwayat Acara")
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                isShowingDonationHistory = true
                            } label: {
                                HStack {
                                    Text("Riwayat Donasi")
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color(#colorLiteral(red: 0.9499571919, green: 0.9500558972, blue: 0.953115046, alpha: 1)))

                        Section("Akun") {
                            Button(role: .destructive) {
                                isShowingDeleteConfirmation = true
                            } label: {
                                Label("Hapus Akun", systemImage: "trash")
                            }
                            .disabled(isDeletingAccount || onDeleteAccount == nil)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                }
                .padding(.top, 12)
            }
            .background(Color(.systemBackground))

            if isShowingLogoutConfirmation {
                ProfileLogoutOverlay(
                    onCancelTapped: { isShowingLogoutConfirmation = false },
                    onLogoutTapped: logout
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isShowingLogoutConfirmation = true
            } label: {
                Text("Keluar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.9, green: 0.32, blue: 0.34))
                    .cornerRadius(28)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.96))
        }
        .navigationBarHidden(true)
        .confirmationDialog(
            "Hapus akun secara permanen?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Hapus Akun", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text(
                "Akun dan data profil akan dihapus. Riwayat donasi tetap disimpan tanpa terhubung "
                    + "ke akun Anda. Tindakan ini tidak dapat dibatalkan."
            )
        }
        .alert(
            "Hapus akun gagal",
            isPresented: Binding(
                get: { deleteAccountError != nil },
                set: {
                    if !$0 {
                        deleteAccountError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountError ?? "Terjadi kesalahan yang tidak diketahui.")
        }
        .fullScreenCover(isPresented: $isShowingEditProfile) {
            DonorProfileEditView(profile: profile) { updated in
                let account = try BackendDependencies.accountClient()
                _ = try await account.updateProfile(AccountProfileUpdate(
                    displayName: updated.fullName,
                    phoneE164: updated.phoneE164,
                    address: updated.address,
                    locationLabel: "",
                    latitude: nil,
                    longitude: nil,
                    avatarObjectPath: updated.avatarObjectPath
                ))
                profile = updated
            }
        }
        .fullScreenCover(isPresented: $isShowingEventHistory) {
            DonorEventHistoryView(
                history: history.completed,
                bannerURL: { history.bannerURL(for: $0) }
            )
        }
        .fullScreenCover(isPresented: $isShowingDonationHistory) {
            DonorDonationHistoryView(donations: history.donations)
        }
        .task {
            async let donations: () = history.loadDonations()
            async let completed: () = history.loadCompleted()
            _ = await (donations, completed)
        }
    }

    private func logout() {
        isShowingLogoutConfirmation = false
        onLogout()
        dismiss()
    }

    private func deleteAccount() async {
        guard let onDeleteAccount, !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await onDeleteAccount()
            dismiss()
        } catch {
            deleteAccountError = error.localizedDescription
        }
    }
}

#Preview {
    @Previewable @State var profile = DonorProfile.defaultProfile

    DonorProfileView(
        profile: $profile
    )
}
