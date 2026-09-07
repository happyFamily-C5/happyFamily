//
//  AppRouter.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 03/09/26.
//

import Observation
import SwiftUI

@Observable
final class AppRouter {
    var adminPath: [AdminsRouter] = []
    var donersPath: [DonersRouter] = []
    var currentStep: Int = 1

    func push(to destination:AdminsRouter) {
        adminPath.append(destination)
    }
    
    func push(to destination:DonersRouter) {
        donersPath.append(destination)
    }
    
    func popToRoot(){
        if !adminPath.isEmpty{
            adminPath.removeAll()
        }
        
        if !donersPath.isEmpty{
            donersPath.removeAll()
        }
    }
    
    func nextStep() {
        currentStep += 1
    }
    
}

extension View {
    func adminsRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: AdminsRouter.self) { destination in
            switch destination {
            case .dashboard:
                DashboardView()
            case .addEvent:
                EmptyView()
            case .openScanner:
                QRScannerView()
            }
        }
    }
    
    func donersRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: DonersRouter.self) { destination in
            switch destination {
            case  .donationFlow:
                DonationFlowView()
            case .scan:
                ClothsView { router.nextStep() }
            case .openCamera:
                ScanView()
            case .result:
                ResultView()
            }
        }
    }
}
