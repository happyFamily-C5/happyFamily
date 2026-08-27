//
//  ShippingMethodCard.swift
//  HappyFamilyAppClips
//
//  Created by binc876 on 27/08/26.
//

import SwiftUI

struct ShippingMethodCard: View {
    let method: ShippingMethodModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                radioButton

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(method.description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.72))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: cardHeight)
            .background(cardBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .stroke(
                        Color.green,
                        lineWidth: 1
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cardHeight: CGFloat {
        switch method {
        case .direct:
            70
        case .expedition, .ojol:
            84
        }
    }

    private var cardBackground: Color {
        isSelected
            ? Color.green
            : Color.gray
    }

    private var radioButton: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected
                        ? Color.red
                        : Color.blue.opacity(0.6),
                    lineWidth: 2
                )
                .frame(width: 18, height: 18)

            if isSelected {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
            }
        }
    }
}
