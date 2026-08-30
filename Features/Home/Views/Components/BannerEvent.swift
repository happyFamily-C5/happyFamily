//
//  BannerEvent.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 24/08/26.
//

import SwiftUI

struct BannerEvent: View {
    let image: Image?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40)
                .fill(AppColor.primaryCyan)

            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Text("There is No Upcoming Event")
                    .font(.headline)
                    .foregroundStyle(AppColor.textDarkCyan)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }
}

#Preview {
    BannerEvent(image: .none)
}
