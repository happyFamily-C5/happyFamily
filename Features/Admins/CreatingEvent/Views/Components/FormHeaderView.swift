import SwiftUI

struct FormHeaderView: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    ForEach(1 ... totalSteps, id: \.self) { step in
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
            stepTitle: "Informasi Dasar"
        )

        FormHeaderView(
            currentStep: 2,
            totalSteps: 3,
            stepTitle: "Lokasi & Waktu"
        )
    }
    .padding(.vertical)
}
