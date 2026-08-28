//
//  ShippingLabelView.swift
//  Recap
//
//  Created by binc876 on 27/08/26.
//

import SwiftUI

struct ShippingLabel: View {
    let senderName: String
    let receiverName: String
    let receiverPhone: String
    let receiverAddress: String
    
    var body: some View {
        VStack(alignment: .leading) {
            // logo
            VStack(alignment: .leading) {
                Image(systemName: "link.circle.fill")
                    .font(.title)
                
                VStack(alignment: .leading) {
                    Text("Recap")
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.textDarkCyan)
                    
                    Text("Give your old clothes a second life.")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textMutedBlue)
                }
                .padding(.top, 4)
            }
            
            // sender + qr
            HStack {
                //QR
                VStack(alignment: .leading) {
                    Image(systemName: "photo")
                }
                .frame(width: 95, height: 95)
                .background(AppColor.baseGrey)

                Spacer()
                    .frame(width: 24)
                
                VStack(alignment: .leading) {
                    Text("Pengirim:")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textMutedBlue)
                    
                    Text(senderName)
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.textDarkCyan)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            // receiver
            VStack(alignment: .leading) {
                Text("Penerima:")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textMutedBlue)
                
                Text(receiverName)
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.textDarkCyan)
                
                Text(receiverPhone)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textDarkCyan)
                
                Text(receiverAddress)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textDarkCyan)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: 300)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

#Preview {
    ShippingLabel(
        senderName: "Bintang", receiverName: "EcoTouch", receiverPhone: "0878-8271-0777", receiverAddress: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11470"
    )
}
