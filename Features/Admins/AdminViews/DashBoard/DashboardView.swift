import SwiftUI
import CoreLocation

struct DashboardView: View {
    
    private let onLogout: () -> Void
    
    @Environment(AppRouter.self) var router
    @Environment(AdminEventStore.self) private var eventStore
    
    
    @State private var searchText: String = ""
    @State private var adminProfile: AdminProfile
    
    // State utama untuk status apakah sudah ada event
    @State private var hasAnyEvent: Bool = false
    //    @State private var isRecapDataEmpty: Bool = true
    
    // State untuk membuka modal CreatingView multi-step
    @State private var isShowingCreateModal: Bool = false
    @State private var isShowingRecapDonation: Bool = false
    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingProfile: Bool = false
    @State private var selectedEvent: AdminEvent?
    
    @State private var userEvents: [AdminEvent] = []
    
    @FocusState private var isSearchFocused: Bool
    
    init(
        initialProfile: AdminProfile = .defaultProfile,
        onLogout: @escaping () -> Void = {}
    ) {
        _adminProfile = State(initialValue: initialProfile)
        self.onLogout = onLogout
    }
    
    private var totalCollectedWeight: Double {
        eventStore.events.reduce(0) { total, event in
            total + event.collectedKg
        }
    }
    
    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            Group {
                if !hasAnyEvent {
                    // MARK: - 1. Empty State Murni
                    VStack {
                        HStack{
                            Image("ecoTouchLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28)
                                .padding(12)
                                .background(
                                    Color(#colorLiteral(red: 1, green: 0.9679821134, blue: 0.8170431256, alpha: 1)),in: Circle()
                                )
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            isShowingProfile = true
                        }
                        
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
                                onLogoTapped: { isShowingProfile = true },
                                onAddTapped: { isShowingCreateModal = true }
                            )
                            
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // A. BAGIAN EVENT BERLANGSUNG (Ongoing)
                                let ongoingEvents = eventStore.events.filter { $0.isOngoing }
                                if !ongoingEvents.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        DashboardTitleView(hasOngoingEvent: true)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 0) {
                                                ForEach(ongoingEvents) { event in
                                                    OngoingEventBanner(
                                                        bannerImage: event.bannerImage,
                                                        title: event.name,
                                                        date: event.formattedDateRange
                                                    ) {
                                                        eventStore.selectedEventID = event.id
                                                        selectedEvent = event
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
                                let upcomingEvents = eventStore.events.filter {
                                    $0.isUpcoming
                                }
                                if !upcomingEvents.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        SectionHeader(title: "Acara mendatang") {
                                            print("Lihat semua acara mendatang")
                                        }
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(upcomingEvents) { event in
                                                    EventCard(
                                                        cardImage: event.bannerImage,
                                                        title: event.name,
                                                        date: event.formattedDateRange
                                                    ) {
                                                        selectedEvent = event
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
                                        isDataEmpty: totalCollectedWeight == 0,
                                        totalWeight:"(\(totalCollectedWeight, default: "%.3f") kg",
                                        periodTitle: "Bulan ini"
                                    ) {
                                        isShowingRecapDonation = true
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 100)
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            
            // While editing, a transparent layer over the dashboard catches
            // taps and resigns focus. It sits above the content but below the
            // search bar, so tapping the field itself still reaches the field,
            // and it only exists while editing so it never interferes
            // otherwise. Attaching the gesture to the content instead was
            // unreliable once the field had text in it.
            if isSearchFocused {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { isSearchFocused = false }
            }
            
            // Floating Search Bar hanya muncul saat dashboard aktif
            if hasAnyEvent {
                FloatingSearchBar(
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused,
                    onMicTapped: { print("Mic diklik!") },
                    onQrTapped: { router.push(to: .openScanner) }
                )
                .padding(.bottom, 16)
            }
        }
        // Only the container's bottom inset (the home indicator) is ignored.
        // The old .edgesIgnoringSafeArea(.bottom) also ignored the *keyboard*
        // safe area, which is why the search bar stayed pinned underneath the
        // keyboard instead of riding above it.
        .ignoresSafeArea(.container, edges: .bottom)
        // CreatingView multi-step (Step 1 - 3). Presented full screen rather
        // than as a sheet: every field lives in its @State, so a card that can
        // be dragged away is an accidental swipe from losing a part-filled
        // form. A full screen cover has no grabber and cannot be swiped at all.
        // The header's back button is the way out — it steps backwards, and
        // closes the flow from step 1.
        .fullScreenCover(isPresented: $isShowingCreateModal) {
            NavigationStack(path: $router.mapPath) {
                CreatingView(
                    onEventCreated: { newEvent in
                        eventStore.events.append(newEvent)
                        hasAnyEvent = true
                    },
                    onViewCreatedEvent: { newEvent in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedEvent = newEvent
                        }
                    }
                )
                .mapPickerRouter(router)
            }
        }
        .fullScreenCover(isPresented: $isShowingRecapDonation) {
            RecapDonation()
        }
        .fullScreenCover(isPresented: $isShowingProfile) {
            ProfileView(
                events: userEvents,
                profile: $adminProfile,
                onLogout: {
                    isShowingProfile = false
                    onLogout()
                }
            )
        }
        .fullScreenCover(item: $selectedEvent) { event in
            EventDetailView(
                event: event,
                onBackTapped: { selectedEvent = nil },
                onShareTapped: { print("Share event: \(event.name)") },
                onEditTapped: { print("Edit event: \(event.name)") },
                onEventUpdated: { updatedEvent in
                    if let index = eventStore.events.firstIndex(
                        where: { $0.id == updatedEvent.id }
                    ) {
                        eventStore.events[index] = updatedEvent
                    }
                    
                    selectedEvent = updatedEvent
                },
                onEventDeleted: { deletedEvent in
                    eventStore.events.removeAll {
                        $0.id == deletedEvent.id
                    }
                    
                    hasAnyEvent = !eventStore.events.isEmpty
                    selectedEvent = nil
                }
            )
        }
        .sheet(isPresented: $isShowingQRScanner) {
            QRScannerView()
        }
    }
}

// MARK: - Model Pendukung untuk Logika Tanggal Event
struct AdminEvent: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let startDate: Date
    let endDate: Date
    let locationName: String
    let locationAddress: String
    let coordinate: CLLocationCoordinate2D?
    let operationalMode: String
    let activeDays: [Bool]
    let startTime: Date
    let endTime: Date
    let donationCriteria: [String]
    let capacityKg: Int
    var collectedKg: Double
    
    /// The cover the organiser picked in CreatingView, kept as Data so the
    /// event stays a plain value type — SwiftUI's Image is not persistable.
    var bannerImageData: Data?
    
    /// The organiser's cover, falling back to the placeholder when they
    /// skipped the picker (the cover is optional in step 1).
    var bannerImage: Image {
        if let bannerImageData, let uiImage = UIImage(data: bannerImageData) {
            return Image(uiImage: uiImage)
        }
        return Image("DummyImageBanner")
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        startDate: Date,
        endDate: Date,
        locationName: String,
        locationAddress: String,
        coordinate: CLLocationCoordinate2D?,
        operationalMode: String,
        activeDays: [Bool],
        startTime: Date,
        endTime: Date,
        donationCriteria: [String],
        capacityKg: Int,
        collectedKg: Double,
        bannerImageData: Data?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.coordinate = coordinate
        self.operationalMode = operationalMode
        self.activeDays = activeDays
        self.startTime = startTime
        self.endTime = endTime
        self.donationCriteria = donationCriteria
        self.capacityKg = capacityKg
        self.collectedKg = collectedKg
        self.bannerImageData = bannerImageData
    }
    
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
    
    var formattedTimeInfo: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm"
        return "\(operationalMode) • \(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DashboardView()
            .environment(AppRouter())
            .environment(AdminEventStore())
    }
}
