//
//  ScanHintView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import SwiftUI

struct ScanHintView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        switch viewModel.phase {
        case .aiming:
            hintRow("Bentangkan satu pakaian dalam bingkai.")
        case .analyzing:
            hintRow("Menganalisis…")
        case .rejected:
            VStack(spacing: 6) {
                Text("TERDETEKSI LEBIH DARI SATU PAKAIAN")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
                Text(
                    "Scan hanya bisa dilakukan untuk satu helai pakaian. "
                        + "Foto ulang dengan satu baju, celana, atau rok saja — "
                        + "pastikan memenuhi bingkai dan tidak ada pakaian lain ikut terlihat."
                )
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        case .reviewing:
            ScanResultsSummaryView(result: viewModel.result)
        }

        if let status = viewModel.statusMessage {
            Text(status).font(.footnote).foregroundStyle(.orange)
        }
    }

    private func hintRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(.white.opacity(0.7))
            Text(text).foregroundStyle(.white.opacity(0.85))
        }
        .font(.subheadline)
    }
}
