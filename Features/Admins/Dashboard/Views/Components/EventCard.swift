import SwiftUI

struct EventCard: View {
    let cardImage: Image?
    let bannerURL: URL?
    let title: String
    let date: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                LoadableEventImage(
                    localImage: cardImage,
                    remoteURL: bannerURL,
                    unavailableLabel: "Banner acara tidak tersedia"
                )
                .frame(width: 170, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 170)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
            EventCard(
                cardImage: Image(systemName: "photo"),
                bannerURL: nil,
                title: "WINCESTER Flea Market",
                date: "APRIL 26 - MAY 11"
            ) {
                print("Card 1 diklik!")
            }

            EventCard(
                cardImage: Image(systemName: "photo"),
                bannerURL: nil,
                title: "Eco Textile Fair",
                date: "JUNE 01 - JUNE 05"
            ) {
                print("Card 2 diklik!")
            }
        }
        .padding(.horizontal, 16)
    }
}
