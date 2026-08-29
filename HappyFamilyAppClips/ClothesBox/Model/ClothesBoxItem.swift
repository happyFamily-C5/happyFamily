//
//  ClothesBoxItem.swift
//  Recap
//
//  Created by Codex on 29/08/26.
//

import Foundation
import UIKit

struct ClothesBoxItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let analysis: ClothingAnalysis
}
