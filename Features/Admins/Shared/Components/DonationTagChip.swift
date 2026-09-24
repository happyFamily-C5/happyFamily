import SwiftUI

struct DonationTagChip: View {
    let title: String
    let isSelected: Bool
    var isCompact: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Berubah otomatis: icon "+" saat belum dipilih, dan "checkmark" saat dipilih
                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: isCompact ? 12 : 12, weight: .bold))

                Text(title)
                    .font(.system(size: isCompact ? 14 : 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, isCompact ? 14 : 16)
            .padding(.vertical, isCompact ? 9 : 10)
            .background(isSelected ? Color("3-DarkSoftCyan") : Color(.systemGray6))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: 12) {
        DonationTagChip(title: "Katun", isSelected: false) {
            print("Chip belum dipilih diklik")
        }

        DonationTagChip(title: "Sutra", isSelected: true) {
            print("Chip terpilih diklik")
        }
    }
    .padding()
}
