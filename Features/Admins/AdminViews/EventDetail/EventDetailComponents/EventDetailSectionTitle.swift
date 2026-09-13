import SwiftUI

struct EventDetailSectionTitle: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)

            Rectangle()
                .fill(Color(.systemGray4))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    EventDetailSectionTitle(title: "Kriteria Donasi")
        .padding(.vertical)
}
