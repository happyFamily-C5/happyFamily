import SwiftUI
import PhotosUI
import UIKit

struct DonorProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    let events: [AdminEvent]
    @Binding var profile: DonorProfile
    var onLogout: () -> Void = {}
    @State private var isShowingEditProfile = false
    @State private var isShowingEventHistory = false
    @State private var isShowingDonationHistory = false
    @State private var isShowingLogoutConfirmation = false
    
    private let donationHistory = DonorDonation.sampleData
    
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
            DonorProfileEditView(
                fullName: $profile.fullName,
                address: $profile.address,
                selectedImageData: $profile.imageData
            )
        }
        .fullScreenCover(isPresented: $isShowingEventHistory) {
            DonorEventHistoryView(events: events)
        }
        .fullScreenCover(isPresented: $isShowingDonationHistory) {
            DonorDonationHistoryView(donations: donationHistory)
        }
    }
    
    private func logout() {
        isShowingLogoutConfirmation = false
        onLogout()
        dismiss()
    }
}

#Preview {
    @Previewable @State var profile = DonorProfile.defaultProfile
    
    DonorProfileView(
        events: [],
        profile: $profile
    )
}
