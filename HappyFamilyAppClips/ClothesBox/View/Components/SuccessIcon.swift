//
//  SuccessIcon.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI

struct SuccessIcon: View {
    var body: some View {
        ZStack {
            sparkle(size: 24, opacity: 1)
                .offset(x: -80, y: -12)
            sparkle(size: 20, opacity: 0.9)
                .offset(x: 30, y: -65)
            sparkle(size: 16, opacity: 0.7)
                .offset(x: 60, y: -40)
            sparkle(size: 20, opacity: 1)
                .offset(x: 75, y: 0)
            sparkle(size: 15, opacity: 0.6)
                .offset(x: -50, y: 50)
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 88))
                .foregroundStyle(.green)
        }
        .frame(width: 100, height: 100)
    }

    private func sparkle(size: CGFloat, opacity: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(.green.opacity(opacity))
    }
}

#Preview {
    SuccessIcon()
}
