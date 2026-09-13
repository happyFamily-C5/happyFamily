import SwiftUI

struct EventHeaderSectionView: View {
    let title: String // Contoh: "Ecotoday | drop your unused shirt" (atau bisa dipisah jika mau)
    let dateRangeText: String // Contoh: "Rab, 9 Sept - 16 Sept 2026"
    let timeInfoText: String // Contoh: "Hari kerja • 09.00 - 16.00"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Judul & Subtitle Event
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            // Tanggal & Jam Kerja
            VStack(alignment: .leading, spacing: 2) {
                Text(dateRangeText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(timeInfoText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EventHeaderSectionView(
        title: "Ecotoday | drop your unused shirt",
        dateRangeText: "Rab, 9 Sept - 16 Sept 2026",
        timeInfoText: "Hari kerja • 09.00 - 16.00"
    )
    .padding()
    .background(Color(.systemBackground))
}
