//
//  ShippingMethodViewModel.swift
//  HappyFamilyAppClips
//
//  Created by binc876 on 27/08/26.
//

import SwiftUI
import Foundation

@Observable
final class ShippingMethodViewModel {

    var selectedMethod: ShippingMethodModel = .direct

    func select(_ method: ShippingMethodModel) {
        selectedMethod = method
    }

    func submit() {
        print("Shipping method: \(selectedMethod.rawValue)")
    }
}
