import SwiftUI

struct DonationBarChartView: View {
    // Data dummy harian (bisa diganti dinamis nanti)
    let chartData: [(day: String, height: CGFloat, weightLabel: String?)] = [
        ("Sen", 90, nil),
        ("Sel", 130, nil),
        ("Rab", 100, nil),
        ("Kam", 60, nil),
        ("Jum", 85, "45 kg"), // Contoh ada tooltip "45 kg" di atas hari Jumat
        ("Sab", 70, nil),
        ("Min", 110, nil)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(chartData, id: \.day) { data in
                    VStack(spacing: 8) {
                        // Tooltip Angka (Muncul jika ada weightLabel)
                        if let label = data.weightLabel {
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color("2-BoldDarkSoftCyan"))
                                .padding(.bottom, 2)
                        } else {
                            // Spacer agar tinggi baris atas tetap sejajar walau tidak ada label
                            Spacer().frame(height: 18)
                        }
                        
                        // Batang Grafik dengan Gradasi & Sudut Melengkung
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color("2-BoldDarkSoftCyan"), // Hijau tua di atas
                                        Color("5-LightSoftCyan")     // Hijau muda di bawah
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 24, height: data.height)
                        
                        // Label Hari (Sen, Sel, Rab, dll)
                        Text(data.day)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    DonationBarChartView()
        .padding()
        .background(Color(.systemGray6))
}
