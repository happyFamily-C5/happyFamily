import SwiftUI

struct FormHeaderView: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitle: String
    var onBackTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Navigation Bar
            HStack {
                Button(action: onBackTapped) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Tambahkan Acara")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            
            // Progress Information & Segmented Bars
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(stepTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                // Segmented Progress Bars (Terpisah menjadi 3 bagian dengan RoundedRectangle)
                HStack(spacing: 8) {
                    ForEach(1...totalSteps, id: \.self) { step in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(step <= currentStep ? Color("3-DarkSoftCyan") : Color(.systemGray5))
                            .frame(height: 6)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 24) {
        FormHeaderView(
            currentStep: 1,
            totalSteps: 3,
            stepTitle: "Informasi Dasar",
            onBackTapped: { print("Back 1") }
        )
        
        FormHeaderView(
            currentStep: 2,
            totalSteps: 3,
            stepTitle: "Lokasi & Waktu",
            onBackTapped: { print("Back 2") }
        )
    }
    .padding(.vertical)
}
