//
//  LandingView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import SwiftUI

struct LandingView: View {

    var body: some View {
        ZStack {
            LandingPalette.backdrop
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                // TODO: Ganti pake logo kita
                BrandMark()

                Text(".kumpul")
                    .font(.title.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(LandingPalette.pine)
                    .padding(.top, 20)

                Spacer(minLength: 28)
            }
        }
    }
}

#Preview { LandingView() }
