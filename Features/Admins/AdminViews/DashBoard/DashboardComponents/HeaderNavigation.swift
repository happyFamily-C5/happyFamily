import SwiftUI

struct HeaderNavigationView: View {
    var onLogoTapped: () -> Void
    var onAddTapped: () -> Void
    
    var body: some View {
        HStack {
            // Tombol Logo / Profil di sebelah kiri (Diubah jadi ikon person.crop.circle.fill warna hitam)
            Button(action: onLogoTapped) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.primary) // Menggunakan warna utama (hitam/gelap di mode light)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Tombol Plus (+) di sebelah kanan
            Button(action: onAddTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    HeaderNavigationView(
        onLogoTapped: { print("Profil diklik") },
        onAddTapped: { print("Tombol plus diklik") }
    )
    .padding()
}
