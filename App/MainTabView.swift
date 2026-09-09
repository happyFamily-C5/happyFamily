//
//  MainTabView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct MainTabView: View {
    @Bindable var router: AppRouter
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home, track
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $router.donersPath) {
                HomeView(userLocation: "Jakarta Pusat")
                .donersRouter(router)
            }
            .tabItem {
                Label("Beranda", systemImage: "house")
            }
            .tag(Tab.home)
            
            NavigationStack(path: $router.donersPath) {
                TrackingHistoryView()
                    .donersRouter(router)
            }
            .tabItem {
                Label("Scan", systemImage: "shippingbox.fill")
            }
            .tag(Tab.track)
        }
    }
}

#Preview {
    MainTabView(router: AppRouter())
        .environment(AppRouter())
        .environment(DonationViewModel())
}
