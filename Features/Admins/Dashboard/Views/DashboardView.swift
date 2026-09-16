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
        backendBaseURL: BackendDependencies.backendBaseURL()
    )

    private var hasAnyEvent: Bool {
        !model.events.isEmpty
    }

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
                    ProgressView("Memuat acara…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasAnyEvent {
                    // MARK: - 1. Empty State Murni

                    VStack {
                        HStack {
                            Image("ecoTouchLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24)
                                .padding(12)
                                .background(
                                    Color(#colorLiteral(red: 1, green: 0.9679821134, blue: 0.8170431256, alpha: 1)), in: Circle()
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
                onDeleteAccount: onDeleteAccount,
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

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
            .environment(AppRouter())
    }
}
