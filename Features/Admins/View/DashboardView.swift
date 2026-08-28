//
//  DashBoard.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct DashBoard: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Spacer()

                    HStack(spacing: 10) {
                        IconButton(
                            systemName: "qrcode",
                            accessibilityLabel: "QR Code"
                        ) {
                            print("QR tapped")
                        }

                        IconButton(
                            systemName: "plus",
                            accessibilityLabel: "Add"
                        ) {
                            print("Add tapped")
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .padding(.top, 16)

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dashboard")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppColor.textColor)

                        Text("Manage your waste")
                            .font(.body)
                            .foregroundStyle(AppColor.textColor)
                    }

                    Spacer()

                    Profile(size: 42)
                        .padding(.top, 8)
                }
                .padding(.top, 34)

                ActiveEvent()
                    .frame(height: 132)
                    .padding(.top, 48)

                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color("2-BoldDarkSoftCyan").opacity(0.72))

                    Text("click \"+\" above to\ncreate a new one!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color("2-BoldDarkSoftCyan").opacity(0.72))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 160)
            }
            .padding(.horizontal, 28)
        }
    }
}

#Preview("Dashboard") {
    DashBoard()
}
