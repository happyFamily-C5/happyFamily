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
        case .reviewing, .rejected:
            // Handled by ScanResultView, which covers this panel.
            EmptyView()
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
