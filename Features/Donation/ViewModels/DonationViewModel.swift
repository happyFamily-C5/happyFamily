//
//  DonationViewModel.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI

@Observable
public class DonationViewModel {
    var name: String = ""
    var phone: String = ""
    
    var agreedToTerms: Bool = false
    
    
    var clothingItems: [ClothingItem] = [
        ClothingItem(image: UIImage(named: "Image 3") ?? UIImage(), isPassed: true)
    ]
    
    // MARK: - Validasi tiap step
    var canProceedFromPersonalInfo: Bool {
        !name.isEmpty && !phone.isEmpty && agreedToTerms
    }
    
    var canProceedFromCapture: Bool {
        !clothingItems.isEmpty
    }
    
    var canProceedFromReview: Bool {
        clothingItems.contains { $0.isPassed == true }
    }
}
