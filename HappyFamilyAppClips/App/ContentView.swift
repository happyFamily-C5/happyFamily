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
            HomeView(
                title: "Ecoday | Drop Your Unused Clothes",
                manager: "EcoTouch Indonesia",
                capacity: 250, maxCapacity: 500
            )
            .donationsRouter(router, donationVM: donationVM)
        }
        .environment(donationVM)
        
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
