import SwiftUI

struct StatisticCardView: View {
    let title: String
    let value: String
    let unit: String
    let backgroundColor: Color
    let systemImageName: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Latar Belakang Gambar / Ikon Transparan di Pojok Kanan Bawah
            Image(systemName: systemImageName)
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.primary.opacity(0.08))
                .offset(x: 16, y: 16)

            // Konten Utama Kartu
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(2)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)

                    Text(unit)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundColor)
        .cornerRadius(24)
        .clipped()
    }
}

// MARK: - Preview dengan 4 Kartu Sesuai Gambar

#Preview(traits: .sizeThatFitsLayout) {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        StatisticCardView(
            title: "Donasi\nterkumpul",
            value: "0",
            unit: "kg",
            backgroundColor: Color(.systemBlue).opacity(0.15),
            systemImageName: "cube.box.fill"
        )

        StatisticCardView(
            title: "Total\npendonasi",
            value: "0",
            unit: "Orang",
            backgroundColor: Color(.systemPurple).opacity(0.15),
            systemImageName: "person.crop.circle.fill"
        )

        StatisticCardView(
            title: "Acara\nSelesai",
            value: "0",
            unit: "Event",
            backgroundColor: Color(.systemGreen).opacity(0.15),
            systemImageName: "calendar.badge.checkmark"
        )

        StatisticCardView(
            title:
            "Rata-Rata\nper-donasi",
            value: "0",
            unit: "kg",
            backgroundColor: Color(.systemRed).opacity(0.15),
            systemImageName: "chart.bar.fill"
        )
    }
    .padding()
}
