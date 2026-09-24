//
//  MainTabView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import CoreLocation
import SwiftUI

struct MainTabView: View {
    @Bindable var router: AppRouter
    var userLocation = "Lokasi Anda"
    var userCoordinate: CLLocationCoordinate2D?
    var onSaveLocation: ((String, CLLocationCoordinate2D) async throws -> Void)?
    @State private var selectedTab: DonersTab = .home

    enum DonersTab: Hashable {
        case home, track
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Beranda", systemImage: "house", value: .home) {
                HomeView(
                    userLocation: userLocation,
                    userCoordinate: userCoordinate,
                    onSaveLocation: onSaveLocation
                )
            }

            Tab("Lacak", systemImage: "shippingbox.fill", value: .track) {
                TrackingHistoryView()
            }
        }
        .environment(router)
    }
}

#Preview {
    MainTabView(router: AppRouter())
        .environment(DonationViewModel())
}
