import SwiftUI

struct DashboardView: View {
    @State private var searchText: String = ""
    
    // State utama untuk status apakah sudah ada event
    @State private var hasAnyEvent: Bool = false
    @State private var isRecapDataEmpty: Bool = true
    
    // State untuk membuka modal CreatingView multi-step
    @State private var isShowingCreateModal: Bool = false
    @State private var isShowingRecapDonation: Bool = false
    
    // Model data event sementara untuk simulasi
    @State private var userEvents: [AdminEvent] = []
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if !hasAnyEvent {
                    // MARK: - 1. Empty State Murni
                    VStack {
                        Spacer()
                        
                        EmptyStateViewDashboard {
                            isShowingCreateModal = true
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    
                } else {
                    // MARK: - 2. Dashboard Aktif
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            HeaderNavigationView(
                                onLogoTapped: { print("Logo / Profile diklik!") },
                                onAddTapped: { isShowingCreateModal = true }
                            )
                            
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // A. BAGIAN EVENT BERLANGSUNG (Ongoing)
                                let ongoingEvents = userEvents.filter { $0.isOngoing }
                                if !ongoingEvents.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        DashboardTitleView(hasOngoingEvent: true)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 0) {
                                                ForEach(ongoingEvents) { event in
                                                    OngoingEventBanner(
                                                        bannerImage: Image("DummyImageBanner"),
                                                        title: event.name,
                                                        date: event.formattedDateRange
                                                    ) {
                                                        print("Ongoing event diklik: \(event.name)")
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 16) {
                                        DashboardTitleView(hasOngoingEvent: false)
                                    }
                                }
                                
                                // B. BAGIAN ACARA MENDATANG (Upcoming)
                                let upcomingEvents = userEvents.filter { $0.isUpcoming }
                                if !upcomingEvents.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        SectionHeader(title: "Acara mendatang") {
                                            print("Lihat semua acara mendatang")
                                        }
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(upcomingEvents) { event in
                                                    EventCard(
                                                        cardImage: Image("DummyImageBanner"),
                                                        title: event.name,
                                                        date: event.formattedDateRange
                                                    ) {
                                                        print("Upcoming event diklik: \(event.name)")
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                
                                // C. SECTION REKAP DONASI
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(
                                        title: "Rekap Donasi",
                                        showArrow: true
                                    ) {
                                        isShowingRecapDonation = true
                                    }
                                    
                                    RecapCard(
                                        isDataEmpty: isRecapDataEmpty,
                                        totalWeight: isRecapDataEmpty ? "0 kg" : "1.045 kg",
                                        periodTitle: "Bulan ini"
                                    ) {
                                        isShowingRecapDonation = true
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 100)
                        }
                    }
                }
            }
            
            // Floating Search Bar hanya muncul saat dashboard aktif
            if hasAnyEvent {
                FloatingSearchBar(
                    searchText: $searchText,
                    onMicTapped: { print("Mic diklik!") },
                    onQrTapped: { print("QR diklik!") }
                )
                .padding(.bottom, 16)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        // Memanggil CreatingView multi-step (Step 1 - 3) di dalam Sheet Modal
        .sheet(isPresented: $isShowingCreateModal) {
            NavigationView {
                CreatingView { newEvent in
                    userEvents.append(newEvent)
                    hasAnyEvent = true
                    isRecapDataEmpty = true
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingRecapDonation) {
            RecapDonation()
        }
    }
}

// MARK: - Model Pendukung untuk Logika Tanggal Event
struct AdminEvent: Identifiable {
    let id = UUID()
    let name: String
    let startDate: Date
    let endDate: Date
    let capacityKg: Int
    var collectedKg: Double
    
    var progress: Double {
        guard capacityKg > 0 else { return 0 }
        return min(collectedKg / Double(capacityKg), 1)
    }
    
    var isOngoing: Bool {
        let today = Date()
        return today >= Calendar.current.startOfDay(for: startDate) && today <= Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
    }
    
    var isUpcoming: Bool {
        let today = Date()
        return startDate > today
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        let startStr = formatter.string(from: startDate).uppercased()
        let endStr = formatter.string(from: endDate).uppercased()
        return "\(startStr) - \(endStr)"
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
}
