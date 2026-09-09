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
        ZStack {
            if router.currentStep == 3 {
                LinearGradient(
                    colors: [Color(red: 0.75, green: 0.85, blue: 0.78), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    HStack{
                        Text("Step \(router.currentStep) of 3")
                            .font(.caption).bold()
                        Spacer()
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
                    ResultView()
                    
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
#Preview {
    DonationFlowView()
        .environment(AppRouter())
        .environment(DonationViewModel())
}
