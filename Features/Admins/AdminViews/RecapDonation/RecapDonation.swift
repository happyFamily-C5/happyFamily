import SwiftUI

struct RecapDonation: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 1. Tombol Back / Navigasi Atas
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // 2. Judul Halaman & Subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rekap Donasi")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Rekap Bulanan")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    
                    // 3. Grid 4 Kartu Statistik (Hardcoded Sesuai Gambar)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatisticCardView(
                            title: "Donasi\nterkumpul",
                            value: "0",
                            unit: "kg",
                            backgroundColor: Color(.systemBlue).opacity(0.15),
                            systemImageName: "cube.box.fill"
                        )
                        
                        StatisticCardView(
                            title: "Total\npendonasi",
                            value: "0",
                            unit: "Orang",
                            backgroundColor: Color(.systemPurple).opacity(0.15),
                            systemImageName: "person.crop.circle.fill"
                        )
                        
                        StatisticCardView(
                            title: "Acara\nSelesai",
                            value: "0",
                            unit: "Event",
                            backgroundColor: Color(.systemGreen).opacity(0.15),
                            systemImageName: "calendar.badge.checkmark"
                        )
                        
                        StatisticCardView(
                            title: "Rata-Rata\nper-donasi",
                            value: "0",
                            unit: "kg",
                            backgroundColor: Color(.systemRed).opacity(0.15),
                            systemImageName: "chart.bar.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // 4. Grafik Batang Harian (Sen - Min)
                    DonationBarChartView()
                        .padding(.horizontal, 16)
                    
                    // 5. Bagian List Donasi Terbaru
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Donasi Terbaru")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            DonationRowView(donorName: "Yuan Dimianta", timeAgo: "1 jam yang lalu", weightText: "4.3 kg")
                            Divider()
                            DonationRowView(donorName: "Calzy Akmal", timeAgo: "2 jam yang lalu", weightText: "4.5 kg")
                            Divider()
                            DonationRowView(donorName: "Sasha Grey", timeAgo: "2 jam yang lalu", weightText: "2.3 kg")
                            Divider()
                            DonationRowView(donorName: "Bintang di langit", timeAgo: "3 jam yang lalu", weightText: "3.6 kg")
                            Divider()
                            DonationRowView(donorName: "Hendra Irawan", timeAgo: "3 jam yang lalu", weightText: "4.8 kg")
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(24)
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationStack {
        RecapDonation()
    }
}
