//
//  AcceptDonationView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 06/09/26.
//

import SwiftUI

struct AcceptDonationView: View {
    var onReturnHome: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Image("Acc")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 152)

                Text("Berhasil !")
                    .font(.title).bold()
            }
            Text("Donasi telah diterima")

            Spacer()

            Button {
                onReturnHome()
            } label: {
                Text("Kembali ke beranda")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        AppColor.primaryCyan,
                        in: RoundedRectangle(cornerRadius: 60)
                    )
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    AcceptDonationView(onReturnHome: {})
}
