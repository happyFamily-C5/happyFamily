//
//  Background.swift
//  Recap
//
//  Created by binc876 on 27/08/26.
//

import SwiftUI

struct Background: View {
    var body: some View {
        LinearGradient(
            colors: [
                AppColor.accentCyan.opacity(0.5),
                AppColor.accentGreen.opacity(0.01)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    Background()
}
