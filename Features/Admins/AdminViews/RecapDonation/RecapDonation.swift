import SwiftUI

struct RecapDonation: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var model = RecapModel(
        reportRepository: BackendDependencies.reportRepositoryOrDefault()
    )
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

                    // 3. Grid 4 Kartu Statistik (Nilai dari operations:recap)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatisticCardView(
                            title: "Donasi\nterkumpul",
                            value: model.collectedKgText,
                            unit: "kg",
                            backgroundColor: Color(.systemBlue).opacity(0.15),
                            systemImageName: "cube.box.fill"
                        )

                        StatisticCardView(
                            title: "Total\npendonasi",
                            value: model.donorCountText,
                            unit: "Orang",
                            backgroundColor: Color(.systemPurple).opacity(0.15),
                            systemImageName: "person.crop.circle.fill"
                        )

                        StatisticCardView(
                            title: "Acara\nSelesai",
                            value: model.completedEventCountText,
                            unit: "Event",
                            backgroundColor: Color(.systemGreen).opacity(0.15),
                            systemImageName: "calendar.badge.checkmark"
                        )

                        StatisticCardView(
                            title: "Rata-Rata\nper-donasi",
                            value: model.averagePerDonationText,
                            unit: "kg",
                            backgroundColor: Color(.systemRed).opacity(0.15),
                            systemImageName: "chart.bar.fill"
                        )
                    }
                    .padding(.horizontal, 16)

                    // 4. Grafik Batang Harian (agregasi 7 hari terakhir)
                    DonationBarChartView(
                        chartData: model.dailyChartTuples
                    )
                    .padding(.horizontal, 16)

                    // 5. Bagian List Donasi Terbaru
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Donasi Terbaru")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            ForEach(model.recentDonations) { donation in
                                DonationRowView(
                                    donorName: donation.donorName,
                                    timeAgo: donation.timeAgoText,
                                    weightText: donation.weightText
                                )
                                if donation.id != model.recentDonations.last?.id {
                                    Divider()
                                }
                            }
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
        .task {
            await model.load()
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationStack {
        RecapDonation()
    }
}
