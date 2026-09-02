import SwiftUI

struct SectionHeader: View {
    let title: String
    var showArrow: Bool = true // Diubah ke true secara default
    var onSeeAllTapped: () -> Void
    
    var body: some View {
        Button(action: onSeeAllTapped) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        SectionHeader(title: "Acara mendatang") {
            print("Acara mendatang diklik")
        }
        
        SectionHeader(title: "Rekap Donasi") {
            print("Rekap Donasi diklik")
        }
    }
    .padding()
}
