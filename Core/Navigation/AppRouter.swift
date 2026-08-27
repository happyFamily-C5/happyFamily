//
//  AppRouter.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI
import Observation

@Observable
public class AppRouter {
    var path: [DonationsRouter] = []
    
    func push(to destination: DonationsRouter){
        path.append(destination)
    }
    
    func pop(){
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot(){
        path.removeAll()
    }
}

extension View {
    func donationsRouter(_ router: AppRouter) -> some View {
        self.navigationDestination(for: DonationsRouter.self) { destination in
            switch destination {
            case  .donationForm:
                FormView()
                
            case .scan:
                FormView()
            case .result:
                FormView()
                
            }
        }
    }
}
