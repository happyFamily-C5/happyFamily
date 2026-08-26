//
//  ClothingFrameOverlay.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import SwiftUI

struct ClothingFrameOverlay: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 300)
        }
    }
}
