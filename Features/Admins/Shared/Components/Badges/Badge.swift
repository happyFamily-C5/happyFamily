//
//  Badge.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct AdminBadge: View {
    let title: String

    init(title: String = "Completed") {
        self.title = title
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

#Preview("Badge") {
    AdminBadge()
        .padding()
}
