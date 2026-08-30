//
//  AddChlotingCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 29/08/26.
//

import SwiftUI

struct AddClothingCard: View {
    var onTap: () -> Void
    
    var body: some View {
        Button{
            onTap()
        }label: {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundColor(.gray.opacity(0.5))
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.35, green: 0.5, blue: 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                )
                .frame(width: 125, height: 149)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )

        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColor.secondaryCyan)
        )
    }
}

#Preview {
    AddClothingCard{}
}
