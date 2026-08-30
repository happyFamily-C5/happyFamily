//
//  ClothingAnalyzer.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import Foundation
import UIKit

struct ClothingAnalyzer {

    enum DebugMode {
        case automatic
        case success
        case needsProcessing
        case multipleDetected
    }

    // Ubah satu baris ini untuk hardcode hasil scan saat debug.
    // `.automatic` memakai heuristic dari ukuran gambar.
    static let debugMode: DebugMode = .success

    func analyze(
        image: UIImage
    ) async -> ClothingAnalysis {

        // Simulate AI processing
        try? await Task.sleep(
            for: .seconds(2)
        )

        switch Self.debugMode {
        case .automatic:
            break
        case .success:
            return ClothingAnalysis(
                detectedAccessories: [],
                hasMultipleItems: false
            )
        case .needsProcessing:
            return ClothingAnalysis(
                detectedAccessories: ["Tag", "Kancing"],
                hasMultipleItems: false
            )
        case .multipleDetected:
            return ClothingAnalysis(
                detectedAccessories: [],
                hasMultipleItems: true
            )
        }

        let size = image.size
        if size.width > size.height * 1.15 {
            return ClothingAnalysis(
                detectedAccessories: [],
                hasMultipleItems: true
            )
        }

        if size.height > size.width * 1.15 {
            return ClothingAnalysis(
                detectedAccessories: ["Tag", "Kancing"],
                hasMultipleItems: false
            )
        }

        return ClothingAnalysis(
            detectedAccessories: [],
            hasMultipleItems: false
        )
    }
}
