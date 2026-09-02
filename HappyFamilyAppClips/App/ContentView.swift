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
    @State private var donationVM = DonationViewModel()

    var body: some View {
        ScanView()
            .environment(donationVM)
    }
}

#Preview {
    ContentView()
}
