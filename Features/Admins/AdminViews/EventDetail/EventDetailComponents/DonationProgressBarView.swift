import SwiftUI

struct DonationProgressBarView: View {
    let currentWeightText: String // Contoh: "250 kg"
    let targetWeightText: String  // Contoh: "Terkumpul dari 500 kg"
    let progressValue: Double     // Nilai dari 0.0 sampai 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text(currentWeightText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(targetWeightText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            // Bar Progress Native
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray4))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("3-DarkSoftCyan"))
                        .frame(width: geometry.size.width * CGFloat(min(max(progressValue, 0.0), 1.0)), height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color("3-DarkSoftCyan").opacity(0.25), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 16)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    DonationProgressBarView(
        currentWeightText: "250 kg",
        targetWeightText: "Terkumpul dari 500 kg",
        progressValue: 0.5
    )
    .padding()
    .background(Color(.systemGray6))
}
