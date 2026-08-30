//
//  ButtonSheet.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI

@MainActor func ButtonSheet( _ title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color)
            .clipShape(Capsule())
    }
    .buttonStyle(.plain)
}
