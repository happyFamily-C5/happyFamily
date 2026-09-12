//
//  DropMethodCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 29/08/26.
//

import SwiftUI

struct DropMethodCard: View {
    var method: String
    var description: String
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                onTap()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: isSelected ? "circle.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppColor.primaryCyan : Color.secondary).bold()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(method)
                            .font(.body).bold()
                        Text(description)
                            .font(.caption2)
                    }
                }
                .padding(16)
                .frame(height: 84)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? AppColor.secondaryCyan : AppColor.baseGrey)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? AppColor.primaryCyan : AppColor.primaryCyan
                                .opacity(0.0)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    DropMethodCard(
        method: "Antar Langsung",
        description: "Kamu membawa langsung paketnya ke lokasi drop-point", isSelected: false

    ) {}
}
