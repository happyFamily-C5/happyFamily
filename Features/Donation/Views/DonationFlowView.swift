//
//  DonationFlowView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 28/08/26.
//

import SwiftUI

struct DonationFlowView: View {
    @State private var currentStep = 1
    

    var body: some View {
        VStack(spacing: 16) {
            StepProgress(currentStep: currentStep, totalStep: 3)

            switch currentStep {
            case 1:
                FormView {
                    currentStep = 2
                }

            case 2:
                ClothsView {
                    currentStep = 3
                }

            case 3:
                ResultView {
                    currentStep = 3
                }

            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
    }
}
#Preview {
    DonationFlowView()
        .environment(AppRouter())
}
