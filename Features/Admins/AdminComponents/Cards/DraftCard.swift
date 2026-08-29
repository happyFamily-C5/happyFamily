//
//  DraftCard.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct DraftCard: View {
    let title: String
    let type: String
    let message: String

    init(
        title: String = "Untitled Work",
        type: String = "Office Donation",
        message: String = "Continue Where You left out"
    ) {
        self.title = title
        self.type = type
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 34))
                .frame(width: 48, height: 54, alignment: .top)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(type)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 10)

                Text(message)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("2-BoldDarkSoftCyan"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColor.textColor)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .leading)
        .background(Color("5-LightSoftCyan"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: .black.opacity(0.12),
            radius: 8,
            y: 4
        )
    }
}

#Preview("Draft Card") {
    ZStack {
        AppColor.baseColor
            .ignoresSafeArea()

        DraftCard()
            .padding(.horizontal, 16)
    }
}
