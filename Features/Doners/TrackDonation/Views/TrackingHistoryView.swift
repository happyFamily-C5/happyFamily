//
//  TrackingView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct TrackingHistoryView: View {
    var body: some View {
        ZStack {
            Color(#colorLiteral(red: 0.9594156146, green: 0.9598115087, blue: 0.9719882607, alpha: 1)).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 32) {
                    ForEach(0..<2){ _ in
                        Button {
                            
                        } label: {
                            TrackCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    TrackingHistoryView()
        .environment(DonationViewModel())
}
