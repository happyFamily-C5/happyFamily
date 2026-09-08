//
//  AccessoryChip.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import SwiftUI

struct AccessoryChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(Color(white: 0.16))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Color(red: 0.99, green: 0.89, blue: 0.89), in: Capsule())
    }
}

#Preview {
    FlowLayout {
        AccessoryChip(label: "Kancing")
        AccessoryChip(label: "Tag")
        AccessoryChip(label: "Resleting")
    }
    .padding()
}
