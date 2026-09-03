//
//  DonationModel.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI

enum DonationStep: Int, CaseIterable {
    case personalInfo = 0
    case capturePhoto
    case reviewItems
}

struct ClothingItem: Identifiable {
    let id = UUID()
    var image: UIImage
    var isPassed: Bool
    var scannerModelVersion: String = "accessory-head-v6"
    var metadata: [String: String] = [:]
}
