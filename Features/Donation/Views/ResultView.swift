//
//  ResultView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 30/08/26.
//

import SwiftUI

struct ResultView: View {
    @Environment(DonationViewModel.self) var donationVM
    @State var isDownloaded = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.75, green: 0.85, blue: 0.78), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                
                // MARK: - Badge Icon
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.35, green: 0.5, blue: 0.45))
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Booking Confirmed!")
                    .font(.title3).bold()
                    .padding(.top, 20)
                
                Text("Unduh label berikut, kemudian cetak dan tempelkan pada paket kardus sebelum dikirim.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                // MARK: - Label Card
                LabelCard(
                    senderName: donationVM.name,
                    receiverName: "EcoTouch Indonesia",
                    receiverPhone: donationVM.phone,
                    receiverAddress: "Jl. Arjuna Utara No.14D, RT.1/RW.1, Tj. Duren Sel., Kec. Grogol petamburan, Kota Jakarta Barat, Daerah Khusus Ibukota Jakarta 11470",
                    qrContent: "dasde1234"
                )
                Spacer()
                
                // MARK: - Buttons
                VStack(spacing: 12) {
                    Button {
                        isDownloaded.toggle()
                    } label: {
                        Text(isDownloaded ? "Selesai" : "Unduh Label")
                            .font(.headline)
                            .foregroundColor(isDownloaded ? .primary : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(isDownloaded ? Color.gray.opacity(0.3) : AppColor.primaryCyan)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }
}

#Preview {
    ResultView()
        .environment(DonationViewModel())
}
