//
//  MaxDonationCard.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 08/09/26.
//

import SwiftUI

struct MaxDonationCard: View {
    
    var maxCapacity: Double
    
    var body: some  View{
        HStack {
            Text("Maksimal Donasi / \nOrang")
                .font(.body).bold()
            Spacer()
            Text("\(maxCapacity, specifier: "%.0f") kg")
                .foregroundStyle(Color.white)
                .font(.title2).bold()
                .padding(10)
                .background(
                    AppColor.primaryCyan,
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .padding(12)
        .background(
            AppColor.secondaryCyan,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

#Preview {
    MaxDonationCard(maxCapacity: 5)
}
