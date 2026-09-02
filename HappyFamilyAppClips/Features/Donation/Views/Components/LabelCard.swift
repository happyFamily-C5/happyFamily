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
        VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    BrandMark(diameter: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(".kumpul")
                            .font(.headline)
                        Text("Give your old clothes a second life.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                
                HStack(spacing: 36) {
                    Image(uiImage: generateQRCode(from: qrContent))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 140, height: 140)
                    
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pengirim:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(senderName)
                            .font(.headline).bold()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            
            
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Penerima:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(receiverName)
                    .font(.headline).bold()
                Text(receiverPhone)
                    .font(.subheadline)
                Text(receiverAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        )
        .padding(.horizontal, 24)
        .padding(.top, 32)
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
