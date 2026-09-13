//
//  ClothingCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 29/08/26.
//

import SwiftUI

struct ClothingCard: View {
    var item: ClothingItem
    let onOpenDetail: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(height: 173)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                onOpenDetail()
            } label: {
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
        }
    }
}

#Preview {
    ClothingCard(
        item: ClothingItem(
            image: UIImage(named: "Image 3") ?? UIImage(),
            isPassed: true
        )
    ) {}
        .environment(AppRouter())
}
