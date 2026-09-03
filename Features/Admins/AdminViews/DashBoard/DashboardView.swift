import SwiftUI

struct DashboardView: View {
    @State private var searchText: String = ""
    @State private var model: DashboardModel
    @State private var isRecapDataEmpty: Bool = true

    // State untuk membuka modal CreatingView multi-step
    @State private var isShowingCreateModal: Bool = false
    @State private var isShowingRecapDonation: Bool = false

    @FocusState private var isSearchFocused: Bool

    init(
        repository: any EventRepository = BackendDependencies.eventRepository(),
        reportRepository: (any ReportRepository)? = BackendDependencies.reportRepositoryOrDefault()
    ) {
        _model = State(initialValue: DashboardModel(
            repository: repository,
            reportRepository: reportRepository
        ))
    }

    private var hasAnyEvent: Bool {
        !model.events.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if model.isLoading, !hasAnyEvent {
                    ProgressView("Memuat acara…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasAnyEvent {
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
                                let ongoingEvents = model.events.filter(\.isOngoing)
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
                                let upcomingEvents = model.events.filter(\.isUpcoming)
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
                    onQrTapped: { print("QR diklik!") }
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
            NavigationView {
                CreatingView { newEvent in
                    isRecapDataEmpty = true
                    Task {
                        await model.createDraft(newEvent)
                        await model.refreshRecap()
                        isRecapDataEmpty = model.isRecapDataEmpty
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingRecapDonation) {
            RecapDonation()
        }
        .task {
            await model.load()
            await model.loadRecap()
            isRecapDataEmpty = model.isRecapDataEmpty
        }
        .onChange(of: model.recapTotalWeightText) {
            isRecapDataEmpty = model.isRecapDataEmpty
        }
        .alert(
            "Backend .kumpul",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "Permintaan gagal.")
        }
    }
}

private extension AdminEvent {
    /// The cover the organiser picked in CreatingView, kept as Data so the
    /// event stays a plain value type — SwiftUI's Image is not persistable.
    var bannerImage: Image {
        if let bannerImageData, let uiImage = UIImage(data: bannerImageData) {
            return Image(uiImage: uiImage)
        }
        return Image("DummyImageBanner")
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}
