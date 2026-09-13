import SwiftUI
import UIKit

struct ProfileHeaderCard: View {
    let imageData: Data?
    let name: String
    let address: String
    var namePlaceholder: String = "Nama Pengelola"
    var addressPlaceholder: String = "Alamat Pengelola"
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 16) {
                    ProfileLogoImage(imageData: imageData, size: 86)

                    VStack(spacing: 8) {
                        Text(name.isEmpty ? namePlaceholder : name)
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(address.isEmpty ? addressPlaceholder : address)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 20)
                .background(
                    LinearGradient(
                        colors: [
                            Color("4-MediumSoftCyan"),
                            Color("3-DarkSoftCyan"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(36)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color(.systemBackground).opacity(0.85))
                    .clipShape(Circle())
                    .padding(14)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileLogoImage: View {
    let imageData: Data?
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            Circle()
                .fill(Color("6-VeryLightSoftCyan"))

            Group {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image("AppLogoIcon")
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.2)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
        .frame(width: size, height: size)
    }
}
