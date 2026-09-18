//
//  UpcomingEvent.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct UpcomingEvent: View {
    let imageName: String
    let width: CGFloat
    let height: CGFloat

    init(
        imageName: String = "Image",
        width: CGFloat = 340,
        height: CGFloat = 180
    ) {
        self.imageName = imageName
        self.width = width
        self.height = height
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color("2-BoldDarkSoftCyan"), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .clipped()
            .accessibilityLabel("Upcoming event")
    }
}

#Preview("Upcoming Event") {
    UpcomingEvent()
        .padding(.horizontal, 16)
}
