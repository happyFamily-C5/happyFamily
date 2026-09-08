//
//  ResultView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 28/08/26.
//

import SwiftUI

struct DropMethodView: View {
    
    @Environment(AppRouter.self) var router
    @Environment(DonationViewModel.self) var donationVM
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
        if let errorMessage = donationVM.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        Button{
            guard let selectedMethod else { return }
            donationVM.selectedShippingMethod = selectedMethod
            Task {
                if await donationVM.createBooking() {
                    router.push(to: .result)
                }
            }
        }label: {
            if donationVM.isCreatingBooking {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("Lanjut")
                .padding()
                .padding(.horizontal, 30)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            AppColor.primaryCyan,
            in: RoundedRectangle(cornerRadius: 30)
        )
        .disabled(selectedMethod == nil || donationVM.isCreatingBooking)
        .opacity(selectedMethod == nil ? 0.55 : 1)
    }
}

#Preview {
    DropMethodView{}
        .environment(AppRouter())
        .environment(DonationViewModel())
}
