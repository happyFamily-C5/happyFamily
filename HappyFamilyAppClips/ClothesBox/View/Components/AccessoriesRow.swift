//
//  AccessoriesRow.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI

func AccessoriesRow( _ accessories: [String]) -> some View {
    HStack(spacing: 8) {
        ForEach(accessories, id: \.self) { accessory in
            Text(accessory.capitalized)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.red.opacity(0.12)))
        }
    }
}
