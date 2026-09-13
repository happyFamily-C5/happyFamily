import SwiftUI

struct OngoingEventBanner: View {
    let bannerImage: Image
    let title: String
    let date: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Banner
                bannerImage
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                LinearGradient(
                    colors: [.black.opacity(0.8), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // 3. Teks Judul dan Tanggal
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(16)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    OngoingEventBanner(
        bannerImage: Image("DummyImageBanner"),
        title: "THE WASTE PROBLEM",
        date: "APRIL 26 - MAY 11"
    ) {
        print("Banner diklik!")
    }
    .padding()
}
