//
//  TrackCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct TrackCard: View {
    @Environment(DonationViewModel.self) var donationVM
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Image("Image 2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 328)
                    .clipShape(RoundedRectangle(cornerRadius:16))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(#colorLiteral(red: 0.4410519004, green: 0.8715734482, blue: 0.5325306058, alpha: 1)))
                                .font(.system(size: 13))
                            Text("Diterima")
                                .foregroundStyle(Color(#colorLiteral(red: 0.4410519004, green: 0.8715734482, blue: 0.5325306058, alpha: 1)))
                                .font(.footnote).bold()
                            Spacer()
                        }
                        
                        Text("EcoTouch Office \nDrop Point")
                            .font(.callout).bold()
                    }
                    
                    VStack(spacing: 4){
                        Text("Nomor Booking")
                            .font(.footnote)
                        Text(donationVM.displayBookingID)
                            .font(.title2).bold()
                    }
                }
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    TrackCard()
        .environment(DonationViewModel())
}
