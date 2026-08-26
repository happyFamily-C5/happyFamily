//
//  ProgressBar.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 25/08/26.
//

import SwiftUI

struct ProgressBar: View {
    var maxCapacity: Int
    var currentCapacity: Int
    var dayLeft: Int

    private var progress: Double {
        guard maxCapacity > 0 else { return 0 }
        return min(
            Double(currentCapacity) / Double(maxCapacity),
            1
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(currentCapacity)) kg")
                            .font(.title2).bold()
                        Text("Terkumpul dari ")
                            .font(.caption2) +
                            Text("\(Int(maxCapacity)) kg")
                            .font(.caption2).bold()
                    }

                    Spacer()

                    Text("\(dayLeft) day left")
                        .font(.body).bold()
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.textColor.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                        .overlay {
                            Capsule()
                                .fill(AppColor.accentColor)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(x: progress, y: 1, anchor: .leading)
                        }
                        .clipShape(Capsule())
                }
                .frame(height: 12)
            }
            .padding(16)
            .background(AppColor.surfaceColor.cornerRadius(28))
        }
    }
}

#Preview {
    ProgressBar(maxCapacity: 500, currentCapacity: 250, dayLeft: 3)
}
