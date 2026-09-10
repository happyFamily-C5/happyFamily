//
//  ScanResultsSummaryView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import SwiftUI

struct ScanResultsSummaryView: View {
    let result: AccessoryScanResult

    private static let palette: [String: Color] = [
        "resleting": .cyan, "saku": .yellow, "ornamen/logam": .orange,
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(result.needsProcessing ? "PERLU DIPROSES" : "AMAN")
                    .font(.title3.bold())
                    .foregroundStyle(result.needsProcessing ? .orange : .green)

                if let type = result.garmentType {
                    Text("\(type.name) · \(String(format: "%.0f%%", type.confidence * 100))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                ForEach(Array(result.grouped.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Self.palette[row.label] ?? .gray)
                            .frame(width: 10, height: 10)
                        Text(row.label).fontWeight(.semibold).foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "%.0f%%", row.confidence * 100))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                if result.present.isEmpty {
                    Text("Tidak ada aksesoris terdeteksi.").foregroundStyle(.white.opacity(0.6))
                }

                Text("Threshold masih dikalibrasi dari foto editorial, belum dari foto HP.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: 220)
    }
}
