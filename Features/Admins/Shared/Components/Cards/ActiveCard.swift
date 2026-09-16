//
//  ActiveCard.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct ActiveCard: View {
    let title: String
    let type: String
    let collectedWeight: Double
    let targetWeight: Double

    private var progressText: String {
        "\(Int(collectedWeight)) kg of \(Int(targetWeight))kg collected"
    }

    init(
        title: String = "December Office collection",
        type: String = "Office Donation",
        collectedWeight: Double = 10,
        targetWeight: Double = 40
    ) {
        self.title = title
        self.type = type
        self.collectedWeight = collectedWeight
        self.targetWeight = targetWeight
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 40))
                .frame(width: 56, height: 64, alignment: .top)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(type)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(progressText)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                ProgressBarCard(value: collectedWeight, total: targetWeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColor.textColor)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, minHeight: 136, maxHeight: 136, alignment: .leading)
        .background(Color("5-LightSoftCyan"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: .black.opacity(0.12),
            radius: 8,
            y: 4
        )
    }
}

#Preview("Active Card") {
    ZStack {
        AppColor.baseColor
            .ignoresSafeArea()

        ActiveCard()
            .padding(.horizontal, 16)
    }
}
