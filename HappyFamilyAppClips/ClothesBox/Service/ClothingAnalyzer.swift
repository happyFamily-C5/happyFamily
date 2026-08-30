//
//  ClothingAnalyzer.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import Foundation
import UIKit

/// Bridges the FeaturePrint head in `FashionModel/Core` to the clip's scan UI.
struct ClothingAnalyzer {

    enum AnalyzeError: LocalizedError {
        case unreadableImage


        var errorDescription: String? {
            switch self {
            case .unreadableImage: "Foto tidak bisa dibaca."
            }
        }
    }

    private let scanner = FeaturePrintScanner()

    /// Fixed, not user-facing — donors shouldn't tune how suspicious the model is.
    private let sensitivity = AccessoryHead.shared.defaultSensitivity

    func analyze(image: UIImage) async throws -> ClothingAnalysis {
        guard let cgImage = image.normalizedUp().cgImage else {
            throw AnalyzeError.unreadableImage
        }
        let scanner = self.scanner
        let level = sensitivity
        let outcome = await Task.detached(priority: .userInitiated) {
            Result { try scanner.scan(cgImage, sensitivity: level) }
        }.value
        return ClothingAnalysis(try outcome.get())
    }
}
