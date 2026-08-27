//
//  UserFormViewModel.swift
//  happyFamily
//
//  Created by Hendra Irawan on 27/08/26.
//

import Foundation


final class UserFormViewModel: ObservableObject {
    
    // MARK: - Form
    @Published var name: String = ""
    @Published var phoneNumber: String = ""
    @Published var email: String = ""
    @Published var isAgreementAccepted: Bool = false
    
    // MARK: - Step
    let currentStep: Int = 1
    let totalStep: Int = 3
    
    //MARK: - Event
    let event = Event(
        title: "Ecoday | drop your\nunused shirt",
        organizer: "EcoTouch Indonesia",
        bannerImageName: "event_banner"
    )
    
    //MARK: - Validation
    var canContinue: Bool {
        return !name.isEmpty && !phoneNumber.isEmpty && isAgreementAccepted
    }
    
    func toggleAgreement() {
        isAgreementAccepted.toggle()
    }
    
    func continueToNextStep() {
        // store data to cloudkit
        // navigate to next step use Router / Coordinator
    }
    
}
