//
//  ClosingBadge.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct ClosingBadge: View {
    let daysRemaining: Int

    private var title: String {
        "Closing in \(daysRemaining) days"
    }

    init(daysRemaining: Int = 4) {
        self.daysRemaining = daysRemaining
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppColor.baseColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color("2-BoldDarkSoftCyan"))
            .clipShape(Capsule())
            .fixedSize()
    }
}

#Preview("Closing Badge") {
    ClosingBadge()
        .padding()
}
