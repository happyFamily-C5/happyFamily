//
//  ResultView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 28/08/26.
//

import SwiftUI

struct DropMethodView: View {
    
    @Environment(AppRouter.self) var router
    @State private var selectedMethod: ShippingMethod?
    
//    var donationVM: DonationViewModel
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mau dikirim pake apa?")
                .font(.title).bold()
            
            Text("Pilih metode pengiriman, dan lakukan pengiriman maksimal dalam 3 hari kedepan.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        
        VStack(spacing: 12) {
            ForEach(ShippingMethod.allCases) { method in
                DropMethodCard(
                    method: method.rawValue,
                    description: method.description,
                    isSelected: selectedMethod == method
                ){
                    selectedMethod = method
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button{
                    if router.currentStep > 1 {
                        router.currentStep -= 1
                    }
                }label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        Spacer()
        Button{
            router.push(to: .result)
        }label: {
            Text("Lanjut")
                .padding()
                .padding(.horizontal, 30)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .background(
                    AppColor.primaryCyan,
                    in: RoundedRectangle(cornerRadius: 30)
                )
        }
    }
}

#Preview {
    DropMethodView{}
        .environment(AppRouter())
}
