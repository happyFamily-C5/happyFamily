import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var profile: AdminProfile
    var onLogout: () -> Void = {}
    var onSaveProfile: ((AdminProfile) async throws -> Void)?
    @State private var isShowingEditProfile = false
    @State private var isShowingEventHistory = false
    @State private var isShowingDonationHistory = false
    @State private var isShowingLogoutConfirmation = false

    @State private var historyModel = AdminHistoryModel(
        historyRepository: BackendDependencies.reportRepositoryOrDefault(),
        receptionRepository: try? BackendDependencies.receptionRepository()
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
                            name: profile.companyName,
                            address: profile.companyAddress,
                            onTap: { isShowingEditProfile = true }
                        )
                        
                        List {
                            Section(
                                header: Text("Aktifitas Terbaru")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.black)
                            ) {
                                Button{
                                    isShowingEventHistory = true
                                }label: {
                                    HStack{
                                        Text("Riwayat Acara")
                                            .font(.body)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 16))
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Button{
                                    isShowingDonationHistory = true
                                }label: {
                                    HStack{
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
        .fullScreenCover(isPresented: $isShowingEditProfile) {
            ProfileEditView(
                companyName: $profile.companyName,
                companyAddress: $profile.companyAddress,
                phoneNumber: $profile.phoneNumber,
                email: $profile.email,
                selectedImageData: $profile.imageData,
                onSave: onSaveProfile
            )
        }
        .fullScreenCover(isPresented: $isShowingEventHistory) {
            ProfileEventHistoryView(model: historyModel)
        }
        .fullScreenCover(isPresented: $isShowingDonationHistory) {
            ProfileDonationHistoryView(model: historyModel)
        }
    }
    
    private func logout() {
        isShowingLogoutConfirmation = false
        onLogout()
        dismiss()
    }
}

#Preview {
    @Previewable @State var profile = AdminProfile.defaultProfile

    ProfileView(profile: $profile)
}
