//
//  ScanResultSheet.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import SwiftUI

struct ScanResultSheet: View {
    enum Outcome: Equatable {
        case checking
        case success
        case needsProcessing(accessories: [String])
    }

    let outcome: Outcome
    var onPrimaryAction: () -> Void = {}

    /// The sheet is always light, even though the scan screen behind it is forced dark.
    private static let heading = Color(white: 0.08)
    private static let secondary = Color(white: 0.44)

    private static let checkmarkImage = UIImage.bundled("checkmark")

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(white: 0.85))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Hasil Scan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.heading)
                .padding(.top, 14)

            content
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.white,
            in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch outcome {
        case .checking:
            checking
        case .success:
            success
        case let .needsProcessing(accessories):
            needsProcessing(accessories)
        }
    }

    /// Roughly what a finished result occupies, so the sheet doesn't jump height
    /// when the scan comes back.
    private static let contentMinHeight: CGFloat = 372

    private var checking: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(Self.secondary)
            Text("Checking the result…")
                .font(.body)
                .foregroundStyle(Self.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: Self.contentMinHeight)
    }

    private var success: some View {
        VStack(spacing: 0) {
            if let checkmark = Self.checkmarkImage {
                Image(uiImage: checkmark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 158)
                    .padding(.top, 34)
            }

            Text("Berhasil !")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Self.heading)
                .padding(.top, 14)

            Text("Pakaian Sudah Sesuai dan berhasil ditambahkan ke lemari.")
                .font(.subheadline)
                .foregroundStyle(Self.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 44)

            primaryButton("Simpan")
                .padding(.top, 30)
        }
    }

    private func needsProcessing(_ accessories: [String]) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 62))
                .foregroundStyle(.red)
                .padding(.top, 36)

            Text("Pakaian Butuh Diproses Lagi")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Self.heading)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 32)

            Text("Lepaskan aksesoris berikut:")
                .font(.subheadline)
                .foregroundStyle(Self.secondary)
                .padding(.top, 18)

            FlowLayout(spacing: 10) {
                ForEach(accessories, id: \.self) { AccessoryChip(label: $0) }
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)

            primaryButton("Foto Ulang")
                .padding(.top, 26)
        }
    }

    private func primaryButton(_ title: String) -> some View {
        Button(action: onPrimaryAction) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.blue, in: Capsule())
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 34)
    }
}

#Preview("Checking") {
    ScanResultSheet(outcome: .checking)
}

#Preview("Berhasil") {
    ScanResultSheet(outcome: .success)
}

#Preview("Butuh Diproses") {
    ScanResultSheet(outcome: .needsProcessing(accessories: ["Kancing", "Tag", "Resleting"]))
}
