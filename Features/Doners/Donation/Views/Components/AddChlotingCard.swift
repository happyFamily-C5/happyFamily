//
//  AddChlotingCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 29/08/26.
//

import SwiftUI

struct AddClothingCard: View {
    @Environment(AppRouter.self) var router
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tambahkan pakaian lagi ?")
                    .font(.body).bold()
                Text("tambahkan lebih banyak pakaian untuk selamatkan lingkungan.")
                    .font(.caption)
            }

            Button {
                router.push(to: .openCamera)
            } label: {
                Text("Tambah")
                    .foregroundStyle(Color.white)
                    .font(.footnote).bold()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        AppColor.primaryCyan,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
        }
        .padding(16)
        .background(
            Color.white, in:
            RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColor.primaryCyan, lineWidth: 2)
        }
    }
}

#Preview {
    AddClothingCard {}
        .environment(AppRouter())
}
