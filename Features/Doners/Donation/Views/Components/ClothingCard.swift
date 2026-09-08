//
//  ClothesCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 29/08/26.
//

import SwiftUI

struct ClothingCard: View {
    
    var item: ClothingItem
    let onOpenDetail: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 149)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Button {
                    onOpenDetail()
                } label: {
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .padding(-10)
                
            }
            .padding(20)
            HStack(spacing: 6) {
                Text(item.isPassed == true ? "Diterima" : "Ditolak")
                    .font(.subheadline).bold()
                
                Image(systemName: item.isPassed == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(item.isPassed == true ? .green : .red)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                (item.isPassed == true ? AppColor.secondaryCyan : Color.red)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColor.secondaryCyan)
        }
        .frame(width: 165, height: 189)
    }
}

#Preview {
    ClothingCard(
        item: ClothingItem(
            image: UIImage(named: "Image 3") ?? UIImage(),
            isPassed: true
        )
    ){}
    .environment(AppRouter())
}
