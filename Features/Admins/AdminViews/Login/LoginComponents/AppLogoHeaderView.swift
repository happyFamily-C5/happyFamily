import SwiftUI

struct AppLogoHeaderView: View {
    var imageName: String = "logotitikkumpul" //nama asset
    var imageSize: CGFloat = 80       // Ukuran logo
    
    var body: some View {
        VStack(spacing: 12) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    AppLogoHeaderView()
        .padding()
        .background(Color(.systemBackground))
}
