//
//  AppRouter.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import Observation
import SwiftUI

@Observable
final class AppRouter {
    var path: [DonationsRouter] = []
    var currentStep: Int = 1

    func push(to destination: DonationsRouter) {
        path.append(destination)
    }
    
    func nextStep() {
        currentStep += 1
    }
    
}

extension View {
    func donationsRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: DonationsRouter.self) { destination in
            switch destination {
            case  .donationFlow:
                DonationFlowView()
            case .scan:
                ClothsView { router.nextStep() }
            case .openCamera:
                ScanView()
            case .result:
                FormView{ router.nextStep() }
            }
        }
    }
}
