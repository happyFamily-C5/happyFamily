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

extension ClothingAnalysis {
    /// `logam` and `ornamen` are separate heads sharing one display label, so the
    /// labels are de-duplicated here rather than listing the same chip twice.
    init(_ result: AccessoryScanResult) {
        var labels: [String] = []
        for finding in result.removable {
            let label = AccessoryHead.shared.displayName(for: finding.attribute)
            if !labels.contains(label) {
                labels.append(label)
            }
        }
        self.init(
            detectedAccessories: labels,
            hasMultipleItems: result.hasMultipleGarments
        )
    }
}
