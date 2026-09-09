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
    /// Version and non-sensitive scanner output are persisted with the booking
    /// contract; photos and embeddings never leave the device.
    var scannerModelVersion: String = "accessory-head-v1"
    var metadata: [String: String] = [:]
}

struct OnboardingSlide: Identifiable {
    let id: Int
    let illustration: String
    let description: String
}

struct GuideSlide: Identifiable {
    let id: Int
    let illustration: String
    let title: String
    let description: String
    
}

struct ScanningGuideSlide: Identifiable {
    let id: Int
    let illustration: String
    let title: String
    let description: String
    
}
