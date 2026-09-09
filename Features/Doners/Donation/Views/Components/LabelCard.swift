//
//  LabelCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 30/08/26.
//

import SwiftUI

struct LabelCard: View {
    
    var senderName: String
    var receiverName: String
    var receiverPhone: String
    var receiverAddress: String
    var qrContent: String
    
    
    var body: some View {
        ZStack {
            ZStack {
                Image("labelCard")
                    .resizable()
                    .scaledToFit()
                
                VStack(alignment: .leading, spacing: 48) {
                    VStack(alignment: .leading, spacing: 4){
                        Image("kumpulLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 118)
                        Text("Give your old clothes a second life.")
                            .foregroundStyle(Color.secondary)
                            .font(.caption).bold()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    
                    HStack(alignment: .top, spacing: 28){
                        Image(uiImage: generateQRCode(from: qrContent))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 95, height: 95)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pengirim:")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(senderName)
                                .font(.title3).bold()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        VStack(alignment: .leading) {
                            Text("Penerima:")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(receiverName)
                                .font(.title3).bold()
                        }
                        Text(receiverAddress)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .aspectRatio(543 / 720, contentMode: .fit)
        }
//        .background(Color.black).ignoresSafeArea()
        .frame(width: 320)
    }
}

#Preview {
    LabelCard(
        senderName: "Bintang",
        receiverName: "EcoTouch Indonesia",
        receiverPhone: "0878-8271-0777",
        receiverAddress: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11470",
        qrContent: "booking-id-12345"
    )
}
