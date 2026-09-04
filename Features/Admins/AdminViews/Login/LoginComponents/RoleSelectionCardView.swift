import SwiftUI

struct RoleSelectionView: View {
    @State private var selectedRole: String? = "Pengelola" // Default pilihan awal
    var onContinueTapped: (String) -> Void
    var onBackTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // 1. Tombol Kembali (<) di Atas
            Button(action: onBackTapped) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .padding(.top, 8)
            
            // 2. Judul & Subjudul
            VStack(alignment: .leading, spacing: 8) {
                Text("Jenis pengguna yang mana anda ?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Untuk memberikan pengalaman yang sesuai, kami perlu mengetahui peran Anda.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            // 3. Pilihan Kartu Peran (Pengelola vs Donatur)
            HStack(spacing: 16) {
                RoleSelectionCardView(
                    title: "Pengelola",
                    imageName: "UserHoldingPhone", // Sesuai permintaan
                    isSelected: selectedRole == "Pengelola"
                ) {
                    selectedRole = "Pengelola"
                    onContinueTapped("Pengelola")
                }
                
                RoleSelectionCardView(
                    title: "Donatur",
                    imageName: "DonerHoldingPhone", // Sesuai nama asset
                    isSelected: selectedRole == "Donatur"
                ) {
                    selectedRole = "Donatur"
                    onContinueTapped("Donatur")
                }
            }
            .padding(.top, 12)
            
            Spacer()
            
            // 4. Tombol Lanjut (PrimaryButton) di Bawah
            PrimaryButton(title: "Lanjut") {
                onContinueTapped(selectedRole ?? "Pengelola")
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct RoleSelectionCardView: View {
    let title: String
    let imageName: String
    let isSelected: Bool
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Circle()
                    .fill(isSelected ? Color("3-DarkSoftCyan") : Color(.systemGray4))
                    .frame(width: 14, height: 14)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color("3-DarkSoftCyan") : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        RoleSelectionView(
            onContinueTapped: { role in print("Lanjut diklik dengan peran \(role)") },
            onBackTapped: { print("Kembali diklik") }
        )
    }
}
