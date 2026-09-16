import SwiftUI

struct SocialAuthButton: View {
    let title: String // Contoh: "Masuk dengan Apple" atau "Daftar dengan Apple"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .semibold))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)
            .cornerRadius(30)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    SocialAuthButton(title: "Masuk dengan Apple") {
        print("Apple Auth diklik")
    }
    .padding()
}
