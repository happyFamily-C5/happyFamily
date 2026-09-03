//
//  ContentView.swift
//  HappyFamilyAppClips
//
//  Created by Hendra Irawan on 21/08/26.
//

import SwiftUI

struct ContentView: View {
    // ScanView replaces staging's CameraScanView, which lived under the
    // ClothesBox tree this branch rewrote into Features/FashionModel/Scan.
    @Environment(AppRouter.self) var router
    @State private var donationVM = DonationViewModel()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            rootContent
                .donationsRouter(router, donationVM: donationVM)
        }
        .environment(donationVM)
        .task {
            await donationVM.loadDevelopmentInvocationIfPresent()
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            router.reset()
            Task {
                await donationVM.handleInvocation(url)
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let event = donationVM.resolvedEvent {
            HomeView(
                title: event.name,
                manager: event.receiverName,
                capacity: Int(event.receivedWeightGrams / 1000),
                maxCapacity: Int(event.capacityGrams / 1000),
                bannerURL: donationVM.bannerURL,
                locationName: event.locationName,
                locationAddress: event.locationAddress,
                latitude: event.latitude,
                longitude: event.longitude,
                acceptsBookings: event.availability.acceptsBookings,
                endsAt: event.endAt
            )
        } else if donationVM.isResolving {
            ProgressView("Memuat acara…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("Acara belum tersedia", systemImage: "link.badge.plus")
            } description: {
                Text(donationVM.errorMessage ?? "Buka App Clip dari tautan atau kode acara .kumpul.")
            } actions: {
                if donationVM.errorMessage != nil {
                    Button("Coba Lagi") {
                        Task { await donationVM.retryResolve() }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
