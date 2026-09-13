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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40)
                .fill(AppColor.primaryCyan)

            if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        fallback
                    } else {
                        ProgressView()
                    }
                }
            } else if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }

    private var fallback: some View {
        Text("Banner acara tidak tersedia")
            .font(.headline)
            .foregroundStyle(AppColor.textDarkCyan)
    }
}

#Preview {
    BannerEvent(image: .none)
}
