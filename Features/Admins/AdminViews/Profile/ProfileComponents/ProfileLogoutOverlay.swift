import SwiftUI

struct ProfileLogoutOverlay: View {
    var onCancelTapped: () -> Void
    var onLogoutTapped: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancelTapped)
            
            VStack(alignment: .leading, spacing: 14) {
                Text("Anda yakin ingin keluar?")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Anda akan keluar dari aplikasi ini dan berhenti menerima notifikasi")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 12) {
                    Button(action: onCancelTapped) {
                        Text("Batal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(22)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onLogoutTapped) {
                        Text("Keluar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.9, green: 0.32, blue: 0.34))
                            .cornerRadius(22)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 260)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 20)
        }
    }
}
