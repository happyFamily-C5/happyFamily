import SwiftUI

struct RecapCard: View {
    let isDataEmpty: Bool
    var totalWeight: String = "1.045 kg"
    var periodTitle: String = "Bulan ini"
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                if isDataEmpty {
                    // MARK: - Empty State
                    VStack(alignment: .center, spacing: 16) {
                        // Ilustrasi atau ikon placeholder untuk rekap kosong
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .frame(width: 80, height: 60)
                            
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .offset(x: 24, y: 16)
                        }
                        .padding(.top, 8)
                        
                        VStack(spacing: 6) {
                            Text("Belum ada data rekap")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Data rekap akan muncul ketika ada event yang telah diselesaikan")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    // MARK: - Filled / Active State (Sesuai kode terakhir yang persis)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(periodTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(totalWeight)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color("2-BoldDarkSoftCyan"))
                        
                        // Grafik Batang dengan Kustomisasi Gradient Warna
                        HStack(alignment: .bottom, spacing: 14) {
                            let chartData: [(height: CGFloat, month: String)] = [
                                (70, "Jan"), (55, "Feb"), (45, "Mar"),
                                (55, "Apr"), (75, "Mei"), (35, "Jun"),
                                (55, "Jul"), (45, "Aug"), (45, "Sep")
                            ]
                            
                            ForEach(chartData, id: \.month) { data in
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color("2-BoldDarkSoftCyan"), // Atas (Tip)
                                                    Color("3-DarkSoftCyan"),     // Tengah
                                                    Color("5-LightSoftCyan")     // Akhir (Bawah)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 22, height: data.height)
                                    
                                    Text(data.month)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview (Menampilkan kedua state sekaligus dalam satu file)
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 24) {
        // 1. Tampilan saat Empty State
        VStack(alignment: .leading, spacing: 8) {
            Text("Rekap Donasi (Empty State)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            RecapCard(isDataEmpty: true) {
                print("Card kosong diklik")
            }
        }
        
    
        VStack(alignment: .leading, spacing: 8) {
            Text("Rekap Donasi (Filled State)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            RecapCard(isDataEmpty: false, totalWeight: "1.045 kg", periodTitle: "Bulan ini") {
                print("Card aktif diklik")
            }
        }
    }
    .padding(.vertical)
    .background(Color(.systemGray6))
}
