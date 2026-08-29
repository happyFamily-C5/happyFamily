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

    func push(to destination: DonationsRouter) {
        path.append(destination)
    }
    
}

extension View {
    func donationsRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: DonationsRouter.self) { destination in
            switch destination {
            case  .donationFlow:
                DonationFlowView()
            case .scan:
                ClothsView{}
            case .result:
                FormView{}
            case .openCamera:
                ScanView()
            }
        }
    }
}
