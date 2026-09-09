import SwiftUI
import CoreLocation

struct DashboardView: View {
    
    private let onLogout: () -> Void
    private let onSaveProfile: ((AdminProfile) async throws -> Void)?
    
    @Environment(AppRouter.self) var router
    
    
    @State private var searchText: String = ""
    @State private var adminProfile: AdminProfile
    
    // State utama untuk status apakah sudah ada event
    // Sumber data: cache backend (DashboardModel), bukan state lokal.
    @State private var model = DashboardModel(
        repository: BackendDependencies.eventRepository(),
        backendBaseURL: BackendDependencies.backendBaseURL()
    )

    private var hasAnyEvent: Bool { !model.events.isEmpty }
    //    @State private var isRecapDataEmpty: Bool = true
    
    // State untuk membuka modal CreatingView multi-step
    @State private var isShowingCreateModal: Bool = false
    @State private var isShowingRecapDonation: Bool = false
    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingProfile: Bool = false
    @State private var selectedEvent: AdminEvent?
    @State private var showShareSheet: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    init(
        initialProfile: AdminProfile = .defaultProfile,
        onLogout: @escaping () -> Void = {},
        onSaveProfile: ((AdminProfile) async throws -> Void)? = nil
    ) {
        _adminProfile = State(initialValue: initialProfile)
        self.onLogout = onLogout
        self.onSaveProfile = onSaveProfile
    }
    
    private var displayEvents: [AdminEvent] {
        model.events
            .map(AdminEvent.init(backend:))
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
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
                                .frame(width: 24)
                                .padding(12)
                                .background(
                                    Color(#colorLiteral(red: 1, green: 0.9679821134, blue: 0.8170431256, alpha: 1)),in: Circle()
                                )
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            router.push(to: AdminsRouter.profile)
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
                                let ongoingEvents = displayEvents.filter { $0.isOngoing }
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
                                                        selectedEvent = event
                                                    }
                                                    .onAppear {
                                                        if event.id == ongoingEvents.last?.id, model.nextCursor != nil {
                                                            Task { await model.loadMore() }
                                                        }
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
                                let upcomingEvents = displayEvents.filter {
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
                                                    .onAppear {
                                                        if event.id == upcomingEvents.last?.id, model.nextCursor != nil {
                                                            Task { await model.loadMore() }
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }

                                // Load/search failures (e.g. CURSOR_INVALID from a
                                // stale pagination cursor) surface here instead of
                                // silently keeping a truncated list.
                                if let errorMessage = model.errorMessage {
                                    VStack(spacing: 8) {
                                        Text(errorMessage)
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                        Button("Muat ulang") {
                                            Task { await model.load() }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
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
                                        isDataEmpty: model.isRecapDataEmpty,
                                        totalWeight: model.recapTotalWeightText,
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
            .task {
                await model.load()
                await model.loadRecap()
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
                    onQrTapped: { isShowingQRScanner = true }
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
                    model: model,
                    onEventCreated: { _ in
                        // Model sudah berisi hasil server lewat createDraft.
                    },
                    onViewCreatedEvent: { local in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedEvent = displayEvents.first(where: { $0.id == local.id }) ?? local
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
                profile: $adminProfile,
                onLogout: {
                    isShowingProfile = false
                    onLogout()
                },
                onSaveProfile: onSaveProfile
            )
        }
        .fullScreenCover(item: $selectedEvent) { event in
            EventDetailView(
                event: event,
                onBackTapped: { selectedEvent = nil },
                onShareTapped: {
                    if model.publishedInvocationURL != nil {
                        showShareSheet = true
                    }
                },
                onEditTapped: { print("Edit event: \(event.name)") },
                onPublishTapped: { ev in
                    let ok = await model.publish(ev.id)
                    return ok ? nil : model.errorMessage
                },
                onEventUpdated: { updatedEvent in
                    // Id sama = upsert; semua event pada pass ini berstatus draft.
                    Task { _ = await model.createDraft(updatedEvent.toBackendAdminEvent()) }
                    selectedEvent = updatedEvent
                },
                onEventDeleted: { deletedEvent in
                    Task { _ = await model.cancelOrDelete(deletedEvent.id) }
                    selectedEvent = nil
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = model.publishedInvocationURL {
                ShareSheet(items: [url])
            }
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

    /// Lifecycle from the server (`list_events` snapshot). Draft-only events
    /// created offline stay `.draft`; publishing flips it locally after the
    /// server call succeeds.
    var status: EventStatusCode = .draft
    
    /// The cover the organiser picked in CreatingView, kept as Data so the
    /// event stays a plain value type — SwiftUI's Image is not persistable.
    var bannerImageData: Data?

    /// Storage path of the uploaded banner, carried through edits so an
    /// untouched banner keeps pointing at the same object server-side.
    var bannerObjectPath: String?

    /// Per-donor donation limit in kilograms (backend: grams).
    var maxDonationPerUserKg: Int?
    
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
        status: EventStatusCode = .draft,
        bannerImageData: Data?,
        bannerObjectPath: String? = nil,
        maxDonationPerUserKg: Int? = nil
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
        self.status = status
        self.bannerImageData = bannerImageData
        self.bannerObjectPath = bannerObjectPath
        self.maxDonationPerUserKg = maxDonationPerUserKg
    }
    
    var progress: Double {
        guard capacityKg > 0 else { return 0 }
        return min(collectedKg / Double(capacityKg), 1)
    }
    
    var isOngoing: Bool {
        switch status {
        case .ongoing:
            return true
        case .draft:
            // Offline drafts keep the legacy date-based placement.
            let today = Date()
            return today >= Calendar.current.startOfDay(for: startDate)
                && today <= Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
        default:
            return false
        }
    }

    var isUpcoming: Bool {
        switch status {
        case .upcoming:
            return true
        case .draft:
            return startDate > Date()
        default:
            return false
        }
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
    }
}
