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
                .fill(AppColor.accentColor)

            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Text("There is No Upcoming Event")
                    .font(.headline)
                    .foregroundStyle(AppColor.baseColor)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
//        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 40))
    }
}

#Preview {
    BannerEvent(image: .none)
}
