//
//  HomeView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 24/08/26.
//

import MapKit
import SwiftUI

/// Donor home driven by `account:dashboard` (active/recommended/trending
/// rails). Every card pushes `account:event_detail` through the router.
/// UI structure follows the staging redesign: the rail titles navigate to
/// the dedicated For You / Trending pages.
struct HomeView: View {
    @Environment(AppRouter.self) private var router

    @State private var userLocation: String
    @State private var selectedAddress: String?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var model: DonorHomeModel

    init(
        userLocation: String = "Lokasi Anda",
        accountClient: (any AccountBackendServing)? = BackendDependencies.accountClientOrDefault(),
        backendBaseURL: URL? = BackendDependencies.backendBaseURL()
    ) {
        _userLocation = State(initialValue: userLocation)
        _model = State(initialValue: DonorHomeModel(
            accountClient: accountClient,
            backendBaseURL: backendBaseURL
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Header

                    HStack(spacing: 12) {
                        locationButton
                        Spacer()
                        Button {
                            router.push(to: .myBookings)
                        } label: {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        Button {
                            router.push(to: .history)
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        Image("ecoTouchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24)
                            .padding(12)
                            .background(
                                Color(#colorLiteral(red: 1, green: 0.9679821134, blue: 0.8170431256, alpha: 1)), in: Circle()
                            )
                            .onTapGesture {
                                router.push(to: DonersRouter.profile)
                            }
                    }
                    .foregroundStyle(.primary)

                    // MARK: - Intro

                    VStack(alignment: .leading, spacing: 4) {
                        Text("""
                        \(Text("Jelajahi ").font(.largeTitle).bold())\
                        \(Text("dan mulai").font(.largeTitle))\
                            \(Text("menjaga lingkungan").font(.largeTitle).bold())
                        """)
                        Text("Temukan acara yang cocok dengan kamu")
                            .font(.callout)
                    }
                }
                .padding(.horizontal, 20)

                railContent
            }
        }
        .task { await model.load() }
        .onChange(of: router.mapPickerSession.revision) { _, _ in
            if let location = router.mapPickerSession.selectedLocation {
                userLocation = location
            }
            selectedAddress = router.mapPickerSession.selectedAddress
            selectedCoordinate = router.mapPickerSession.selectedCoordinate
        }
    }

    private var locationButton: some View {
        Button {
            router.openDonersMapPicker(
                location: userLocation,
                address: selectedAddress,
                coordinate: selectedCoordinate
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 20))
                Text(userLocation)
                    .bold()
                Image(systemName: "chevron.down")
                    .font(.system(size: 17)).bold()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var railContent: some View {
        if model.isLoading, model.dashboard == nil {
            VStack {
                ProgressView("Memuat acara…")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = model.errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Coba lagi") {
                    Task { await model.load() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let dashboard = model.dashboard {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    if !dashboard.profileComplete {
                        Text("Lengkapi profil untuk mulai berdonasi.")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }

                    activeRail(dashboard.activeEvents)
                    recommendedRail(dashboard.recommendedEvents)
                    trendingRail(dashboard.trendingEvents)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    private func activeRail(_ events: [DonorEventDTO]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Acara Aktif Kamu")
                .font(.title2).bold()
            if events.isEmpty {
                Text("Belum ada acara aktif. Donasi berjalanmu tampil di sini.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(events) { event in
                            Button {
                                router.push(to: .eventDetail(event.id))
                            } label: {
                                BannerEvent(image: nil, remoteURL: model.bannerURL(for: event))
                                    .frame(width: 320)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func recommendedRail(_ events: [DonorEventDTO]) -> some View {
        eventRail(
            title: "Untuk Kamu",
            events: events,
            route: .forYouPage
        )
    }

    private func trendingRail(_ events: [DonorEventDTO]) -> some View {
        eventRail(
            title: "Sedang Tren",
            events: events,
            route: .trendPage
        )
    }

    private func eventRail(title: String, events: [DonorEventDTO], route: DonersRouter? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let route {
                    Button {
                        router.push(to: route)
                    } label: {
                        railTitle(title)
                    }
                    .buttonStyle(.plain)
                } else {
                    railTitle(title)
                }
                Spacer()
            }
            if events.isEmpty {
                Text("Belum ada acara yang tersedia.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(events) { event in
                            Button {
                                router.push(to: .eventDetail(event.id))
                            } label: {
                                EventRailCard(
                                    title: event.name,
                                    subtitle: event.organizationName ?? "EcoTouch",
                                    distanceText: model.distanceText(for: event),
                                    bannerURL: model.bannerURL(for: event)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func railTitle(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.title2).bold()
            Image(systemName: "chevron.right")
                .font(.system(size: 15)).bold()
                .foregroundStyle(Color.secondary)
        }
    }
}

private struct EventRailCard: View {
    let title: String
    let subtitle: String
    let distanceText: String?
    let bannerURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            banner
                .frame(width: 180, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout).bold()
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Text(subtitle)
                        .font(.footnote)
                        .lineLimit(1)
                    if let distanceText {
                        Text("· \(distanceText)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let bannerURL {
            AsyncImage(url: bannerURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image("eventBanner")
            .resizable()
            .scaledToFill()
    }
}

#Preview {
    HomeView(userLocation: "Jakarta Pusat")
        .environment(AppRouter())
}
