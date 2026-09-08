//
//  DonationFlowView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 28/08/26.
//

import SwiftUI

struct DonationFlowView: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                HStack{
                    Spacer()
                    Text("Step \(router.currentStep) of 3")
                        .font(.caption).bold()
                }
            StepProgress(currentStep: router.currentStep, totalStep: 3)
            }

            switch router.currentStep {
            case 1:
                FormView {
                    router.currentStep = 2
                }

            case 2:
                ClothsView {
                    router.currentStep = 3
                }

            case 3:
                DropMethodView {
                    router.currentStep = 3
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
        .environment(DonationViewModel())
}
