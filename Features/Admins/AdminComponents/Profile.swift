//
//  Profile.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct Profile: View {
    let size: CGFloat

    init(size: CGFloat = 92) {
        self.size = size
    }

    var body: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(AppColor.baseColor, Color("2-BoldDarkSoftCyan"))
            .frame(width: size, height: size)
            .accessibilityLabel("Profile")
    }
}

#Preview("Profile") {
    Profile()
        .padding()
}
