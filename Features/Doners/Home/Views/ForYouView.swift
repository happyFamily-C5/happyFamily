//
//  ForYouView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct ForYouView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
            ForEach(0..<9){ _ in
                    ForYouCard(
                        name: "EcoTouch Indonesia",
                        title: "Ecoday Shirt | drop your unused shirt",
                        startDate: "9 Sept",
                        endDate: "16 Sept",
                        location: "EcoTouch Office"
                    )
                }
            }
        }
        .navigationTitle("Untuk Kamu")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ForYouView()
    }
}
