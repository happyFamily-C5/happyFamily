//
//  ScanResultView.swift
//  Recap
//
//  Created by binc876 on 29/08/26.
//

import SwiftUI
import UIKit

struct ScanResultView: View {
    let count: Int
    let imageAtIndex: (Int) -> UIImage
    let onPreview: (Int) -> Void
    let onAdd: () -> Void

    private let cardSize = CGSize(width: 165, height: 189)

    private let columns = [
        GridItem(.fixed(165), spacing: 20),
        GridItem(.adaptive(minimum: 165, maximum: .infinity))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                // grid untuk menampilkan pakaian
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(0..<count, id: \.self) { index in
                        imageCard(
                            image: imageAtIndex(index),
                            index: index
                        )
                    }
                    
                    addCell
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func imageCard(
        image: UIImage,
        index: Int
    ) -> some View {
        Button {
            onPreview(index)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: cardSize.width,
                        height: cardSize.height
                    )
                    .clipped()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
                    .padding(8)
            }
            .overlay(alignment: .bottom) {
                statusBadge
                    .padding(.bottom, 10)
            }
            .frame(
                width: cardSize.width,
                height: cardSize.height
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        Label("Diterima", systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.white.opacity(0.9))
            )
    }

    private var addCell: some View {
        Button {
            onAdd()
        } label: {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    Color.secondary.opacity(0.35),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: [6]
                    )
                )
                .frame(
                    width: cardSize.width,
                    height: cardSize.height
                )
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(AppColor.primaryCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScanResultView(
        count: 5,
        imageAtIndex: { _ in UIImage() },
        onPreview: { _ in },
        onAdd: {}
    )
}
