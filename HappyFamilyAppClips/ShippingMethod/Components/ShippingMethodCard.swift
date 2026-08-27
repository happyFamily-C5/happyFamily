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

            HStack(alignment: .center, spacing: 12) {

                radioButton

                VStack(alignment: .leading, spacing: 4) {

                    Text(method.rawValue)
                        .font(.body.bold())
                        .foregroundStyle(AppColor.textDarkCyan)

                    Text(method.description)
                        .font(.caption2)
                        .foregroundStyle(AppColor.textDarkCyan)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(0)
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
                        AppColor.primaryCyan,
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
            return 70
        case .ojol:
            return 84
        case .expedition:
            return 84
        }
    }

    private var cardBackground: Color {
        isSelected
        ? AppColor.secondaryCyan
        : AppColor.baseGrey
    }

    private var radioButton: some View {
        ZStack {

            Circle()
                .stroke(
                    isSelected
                    ? AppColor.primaryCyan
                        : Color.gray,
                    lineWidth: 2
                )
                .frame(width: 18, height: 18)

            if isSelected {
                Circle()
                    .fill(AppColor.primaryCyan)
                    .frame(width: 10, height: 10)
            }
        }
    }
}
