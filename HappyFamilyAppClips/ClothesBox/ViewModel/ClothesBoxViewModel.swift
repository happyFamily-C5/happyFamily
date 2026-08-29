//
//  ClothesBoxViewModel.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import Observation
import UIKit

@MainActor
@Observable
final class ClothesBoxViewModel {

    var items: [ClothesBoxItem] = []

    var showCamera = false

    var showPreview = false

    var previewItem: ClothesBoxItem?

    var canContinue: Bool {
        !items.isEmpty
    }

    func openCamera() {
        showCamera = true
    }

    func addImage(
        _ image: UIImage,
        analysis: ClothingAnalysis
    ) {
        items.append(
            ClothesBoxItem(
                image: image,
                analysis: analysis
            )
        )
    }

    func openPreview(for item: ClothesBoxItem) {
        previewItem = item
        showPreview = true
    }

    func removeImage(at index: Int) {
        guard items.indices.contains(index) else {
            return
        }

        items.remove(at: index)
    }
}
