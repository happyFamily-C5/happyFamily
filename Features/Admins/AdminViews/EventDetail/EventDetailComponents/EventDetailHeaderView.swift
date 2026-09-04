import SwiftUI

struct EventDetailHeaderView: View {
    let bannerImage: Image
    var onBackTapped: () -> Void
    var onShareTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .top) {
            bannerImage
                .resizable()
                .scaledToFill()
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
            
            // 2. Tombol Navigasi Mengapung Tepat di Atas Gambar
            HStack {
                Button(action: onBackTapped) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                }
                
                Spacer()
                
                Button(action: onShareTapped) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EventDetailHeaderView(
        bannerImage: Image("DummyImageBanner"),
        onBackTapped: { print("Back diklik") },
        onShareTapped: { print("Share diklik") }
    )
    .padding(.vertical)
}
