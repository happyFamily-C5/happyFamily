//
//  ClothingAnalysis.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import Foundation

struct ClothingAnalysis {

    let detectedAccessories: [String]
    let hasMultipleItems: Bool

    var scanOutcome: ScanOutcome {
        if hasMultipleItems {
            return .multipleDetected
        } else if !detectedAccessories.isEmpty {
            return .needsProcessing
        } else {
            return .success
        }
    }

    var isValid: Bool {
        scanOutcome == .success
    }

    var title: String {
        switch scanOutcome {
        case .needsProcessing:
            return "Pakaian Butuh Diproses Lagi"
        case .success:
            return "Pakaian sesuai!"
        case .multipleDetected:
            return "Terdeteksi Lebih Dari Satu Pakaian"
        }
    }

    var description: String {
        switch scanOutcome {
        case .needsProcessing:
            return "Lepaskan aksesoris sebelum menyimpan pakaian ini."
        case .success:
            return "Pakaian memenuhi kriteria untuk didonasikan."
        case .multipleDetected:
            return "Scan hanya bisa untuk satu pakaian dalam satu foto."
        }
    }
}

enum ScanOutcome {
    case needsProcessing
    case success
    case multipleDetected
}
