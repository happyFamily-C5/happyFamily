import SwiftUI

struct DonationRowView: View {
    let donorName: String
    let timeAgo: String
    let weightText: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(donorName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(timeAgo)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(weightText)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color("3-DarkSoftCyan"))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 12) {
        DonationRowView(donorName: "Yuan Dimianta", timeAgo: "1 jam yang lalu", weightText: "4.3 kg")
        Divider()
        DonationRowView(donorName: "Calzy Akmal", timeAgo: "2 jam yang lalu", weightText: "4.5 kg")
    }
    .padding(16)
    .background(Color(.systemBackground))
    .cornerRadius(20)
    .padding()
}
