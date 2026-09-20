//
//  BannerEvent.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 24/08/26.
//

import SwiftUI

struct BannerEvent: View {
    let image: Image?
    var remoteURL: URL?

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        ZStack {
            shape.fill(AppColor.primaryCyan)

            LoadableEventImage(
                localImage: image,
                remoteURL: remoteURL,
                unavailableLabel: "Banner acara tidak tersedia"
            )
        }
        .frame(width: 320, height: 180)
        .clipShape(shape)
    }
}

#Preview {
    BannerEvent(image: .none)
}
