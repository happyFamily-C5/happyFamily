//
//  BundledImage.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import UIKit

extension UIImage {
    /// Loose PNGs under `FashionModel/Assets` are copied to the bundle root rather than
    /// compiled into an asset catalog, so `Image("name")` can't resolve them.
    static func bundled(_ name: String) -> UIImage? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png") else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
