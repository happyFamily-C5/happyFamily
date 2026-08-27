//
//  BookingConfirmedView.swift
//  Recap
//
//  Created by binc876 on 27/08/26.
//

import SwiftUI

struct BookingConfirmedView: View {
    var body: some View {
        ZStack {
            //background
            Background()
            
            VStack {
                ScrollView {
                    VStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppColor.primaryCyan)
                            .padding(.bottom, 4)
                        
                        Text("Booking Confirmed!")
                            .font(.title.bold())
                            .foregroundColor(AppColor.textDarkCyan)
                        
                        Text("Unduh label berikut, kemudian cetak dan tempelkan pada paket kardus sebelum dikirim.")
                            .font(.footnote)
                            .foregroundColor(AppColor.textDarkCyan)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)
                    
                    //label box
                    ShippingLabel(senderName: "Bintang Laily", receiverName: "EcoTouch Indonesia", receiverPhone: "0878-8271-0777", receiverAddress: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11470")
                }
                
                //buttons
                VStack {
                    Button {
                        //download
                    } label: {
                        Text("Unduh Label")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(AppColor.primaryGreen)
                            )
                    }
                    
                    Button {
                        //selesai
                    } label: {
                        Text("Selesai")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColor.textDarkCyan)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(AppColor.baseGrey)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 0)
            }
        }
    }
}

#Preview {
    BookingConfirmedView()
}
