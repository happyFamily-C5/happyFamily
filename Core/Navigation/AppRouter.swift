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
    var path: [AdminsRouter] = []
    var currentStep: Int = 1

    func push(to destination:AdminsRouter) {
        path.append(destination)
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
            }
        }
    }
}
