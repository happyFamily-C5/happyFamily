import CoreLocation
import SwiftUI

struct DashboardView: View {
    private let onLogout: () -> Void
    private let onDeleteAccount: (() async throws -> Void)?
    private let onSaveProfile: ((AdminProfile) async throws -> Void)?
    
    @Environment(AppRouter.self) var router
    
    @State private var searchText: String = ""
    @State private var selectedStatus: EventStatusCode?
    @State private var adminProfile: AdminProfile
    
    /// State utama untuk status apakah sudah ada event
    /// Sumber data: cache backend (DashboardModel), bukan state lokal.
    @State private var model = DashboardModel(
        repository: BackendDependencies.eventRepository(),
        reportRepository: BackendDependencies.reportRepositoryOrDefault(),
        backendBaseURL: BackendDependencies.backendBaseURL()
    )
    
    private var hasAnyEvent: Bool {
        !model.events.isEmpty
    }
    
    //    @State private var isRecapDataEmpty: Bool = true
    
    // State untuk membuka modal CreatingView multi-step
    @State private var isShowingCreateModal: Bool = false
    @State private var isShowingRequiredProfile: Bool = false
    @State private var shouldOpenCreateAfterProfileSave = false
    @State private var isShowingRecapDonation: Bool = false
    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingProfile: Bool = false
    @State private var selectedEvent: AdminEvent?
    @State private var showShareSheet: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    init(
        initialProfile: AdminProfile = .defaultProfile,
        onLogout: @escaping () -> Void = {},
        onDeleteAccount: (() async throws -> Void)? = nil,
        onSaveProfile: ((AdminProfile) async throws -> Void)? = nil
    ) {
        _adminProfile = State(initialValue: initialProfile)
        self.onLogout = onLogout
        self.onDeleteAccount = onDeleteAccount
        self.onSaveProfile = onSaveProfile
    }
    
    private var displayEvents: [AdminEvent] {
        model.events
            .map(AdminEvent.init(backend:))
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .filter { selectedStatus == nil || $0.status == selectedStatus }
    }
    
    var body: some View {
        @Bindable var router = router
        
        ZStack(alignment: .bottom) {
            Group {
                if model.isLoading, model.events.isEmpty {
                    AdminDashboardSkeleton()
                } else if !hasAnyEvent {
                    // MARK: - 1. Empty State Murni
                    
                    VStack {
                        EmptyStateViewDashboard {
                            requestCreateEvent()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    
                } else {
                    // MARK: - 2. Dashboard Aktif
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            Menu {
                                Button("Semua status") { selectedStatus = nil }
                                ForEach(EventStatusCode.allCases, id: \.self) { status in
                                    Button(AdminEvent.statusLabel(status)) {
                                        selectedStatus = status
                                    }
                                }
                            } label: {
                                Label(
                                    selectedStatus.map(AdminEvent.statusLabel) ?? "Semua status",
                                    systemImage: "line.3.horizontal.decrease.circle"
                                )
                                .font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 16)
                            
                            VStack(alignment: .leading, spacing: 24) {
                                // A. BAGIAN EVENT BERLANGSUNG (Ongoing)
                                let ongoingEvents = displayEvents.filter(\.isOngoing)
                                if !ongoingEvents.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        DashboardTitleView(hasOngoingEvent: true)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 0) {
                                                ForEach(ongoingEvents) { event in
                                                    OngoingEventBanner(
                                                        bannerImage: event.localBannerImage,
                                                        bannerURL: model.bannerURL(for: event.bannerObjectPath),
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
                                let upcomingEvents = displayEvents.filter(\.isUpcoming)
                                if !upcomingEvents.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        SectionHeader(title: "Acara mendatang") {
                                            print("Lihat semua acara mendatang")
                                        }
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(upcomingEvents) { event in
                                                    EventCard(
                                                        cardImage: event.localBannerImage,
                                                        bannerURL: model.bannerURL(for: event.bannerObjectPath),
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
                                    
                                    if !model.hasLoadedRecap || model.isRecapLoading {
                                        ProgressView("Memuat rekap…")
                                            .frame(maxWidth: .infinity, minHeight: 150)
                                    } else if model.recap == nil {
                                        VStack(spacing: 8) {
                                            Text(model.recapErrorMessage ?? "Rekap belum tersedia.")
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                            Button("Muat ulang rekap") {
                                                Task { await model.refreshRecap() }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 16)
                                    } else {
                                        RecapCard(
                                            isDataEmpty: model.isRecapDataEmpty,
                                            chartData: model.dailyChartTuples
                                        ) {
                                            isShowingRecapDonation = true
                                        }
                                        
                                        if let recapErrorMessage = model.recapErrorMessage {
                                            Button("Muat ulang rekap") {
                                                Task { await model.refreshRecap() }
                                            }
                                            .font(.footnote)
                                            .frame(maxWidth: .infinity)
                                            .accessibilityHint(recapErrorMessage)
                                        }
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 100)
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .refreshable {
                        await model.refresh()
                    }
                }
            }
            .task {
                await model.load()
                await model.loadRecap()
            }
            .onReceive(NotificationCenter.default.publisher(for: .adminOperationsDidChange)) { _ in
                Task {
                    await model.load()
                    await model.refreshRecap()
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
                    onQrTapped: { isShowingQRScanner = true }
                )
                .padding(.bottom, 16)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button{
                    openAdminProfile()
                }label: {
                    Image("ecoTouchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.profileBackground)
                .accessibilityLabel("Buka profil")
                .accessibilityIdentifier("dashboardProfile")
            }
            
            if hasAnyEvent{
                ToolbarItem(placement: .topBarTrailing) {
                    Button{
                        requestCreateEvent()
                    }label: {
                        Image(systemName: "plus")
                    }
                }
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
        .fullScreenCover(
            isPresented: $isShowingRequiredProfile,
            onDismiss: resumeEventCreationAfterProfileSave
        ) {
            RegisterOrganizationInfoView(profile: adminProfile) { updated in
                guard let onSaveProfile else {
                    throw BackendError.configuration("penyimpanan profil pengelola")
                }
                try await onSaveProfile(updated)
                adminProfile = updated
                shouldOpenCreateAfterProfileSave = true
            }
        }
        .fullScreenCover(isPresented: $isShowingRecapDonation) {
            RecapDonation()
        }
        .sheet(isPresented: $isShowingProfile) {
            ProfileView(
                profile: $adminProfile,
                onLogout: {
                    isShowingProfile = false
                    onLogout()
                },
                onDeleteAccount: onDeleteAccount,
                onSaveProfile: onSaveProfile
            )
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $selectedEvent) { event in
            EventDetailView(
                event: event,
                bannerURL: model.bannerURL(for: event.bannerObjectPath),
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
    
    private func requestCreateEvent() {
        if ProfileCompletionPolicy.canCreateEvent(adminProfile) {
            isShowingCreateModal = true
        } else {
            isShowingRequiredProfile = true
        }
    }
    
    private func openAdminProfile() {
        isShowingProfile = true
    }
    
    private func resumeEventCreationAfterProfileSave() {
        guard shouldOpenCreateAfterProfileSave else { return }
        shouldOpenCreateAfterProfileSave = false
        isShowingCreateModal = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
            .environment(AppRouter())
    }
}

private struct AdminDashboardSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    SkeletonBlock(cornerRadius: 20)
                        .frame(width: 48, height: 48)
                    Spacer()
                    SkeletonBlock(cornerRadius: 20)
                        .frame(width: 48, height: 48)
                }
                .padding(.horizontal, 20)
                
                SkeletonBlock(cornerRadius: 6)
                    .frame(width: 130, height: 20)
                    .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonBlock(cornerRadius: 6)
                        .frame(width: 190, height: 22)
                    
                    SkeletonBlock(cornerRadius: 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                }
                .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonBlock(cornerRadius: 6)
                        .frame(width: 160, height: 22)
                    
                    HStack(spacing: 16) {
                        ForEach(0 ..< 2, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonBlock(cornerRadius: 16)
                                    .frame(width: 170, height: 140)
                                SkeletonBlock(cornerRadius: 5)
                                    .frame(width: 130, height: 15)
                                SkeletonBlock(cornerRadius: 5)
                                    .frame(width: 100, height: 12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonBlock(cornerRadius: 6)
                        .frame(width: 140, height: 22)
                    SkeletonBlock(cornerRadius: 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                }
                .padding(.horizontal, 16)
                
                Spacer().frame(height: 100)
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
            .skeleton(isLoading: true)
        }
    }
}
