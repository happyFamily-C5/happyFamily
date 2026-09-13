//
//  MainTabView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct MainTabView: View {
    @Bindable var router: AppRouter
    var userLocation = "Lokasi Anda"
    @State private var selectedTab: DonersTab = .home

    enum DonersTab: Hashable {
        case home, track
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Beranda", systemImage: "house", value: .home) {
                HomeView(userLocation: userLocation)
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
