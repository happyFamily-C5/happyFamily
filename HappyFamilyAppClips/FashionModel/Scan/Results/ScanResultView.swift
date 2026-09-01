//
//  ScanResultView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import SwiftUI

struct ScanResultView: View {
    let photo: UIImage?
    let outcome: ScanResultSheet.Outcome
    var onClose: () -> Void = {}
    var onPrimaryAction: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ScanResultSheet(outcome: outcome, onPrimaryAction: onPrimaryAction)
            }

            HStack {
                CircleIconButton(systemImage: "xmark", action: onClose)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var backdrop: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.62)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(Color.black.opacity(0.22))
        .ignoresSafeArea()
    }
}

#Preview("Checking") {
    ScanResultView(photo: nil, outcome: .checking)
}

#Preview("Berhasil") {
    ScanResultView(photo: nil, outcome: .success)
}

#Preview("Butuh Diproses") {
    ScanResultView(
        photo: nil,
        outcome: .needsProcessing(accessories: ["Kancing", "Tag", "Resleting"])
    )
}
