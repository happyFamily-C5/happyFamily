//
//  FormView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 26/08/26.
//

import SwiftUI

struct FormView: View {
    @Environment(DonationViewModel.self) var donationVM
    @Environment(AppRouter.self) var router
    @State var showNameError = false
    @State var showPhoneError = false
    
    let onNext: () -> Void
    
    var body: some View {
        @Bindable var donationVM = donationVM
        
        VStack(alignment: .leading, spacing: 36) {
            VStack(spacing: 16){
                
                HStack(spacing: 16){
                    Image("Image 2")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    VStack(alignment: .leading, spacing: 4){
                        Text("Ecoday | Drop Your Unused Shirt")
                            .font(.title).bold()
                        Text("EcoTouch Indonesia")
                            .font(.headline)
                        
                    }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Personal Information")
                        .font(Font.title.bold())
                    Divider()
                }
                VStack(alignment: .leading, spacing: 8){
                    Text("Name")
                        .font(.body)
                    TextField("Enter your name", text: $donationVM.name)
                        .padding(20)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 30))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(
                                    showNameError ? Color.red : Color.red.opacity(0.0)
                                )
                        )
                    if showNameError {
                        Text("*Name is required")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8){
                    Text("Phone Number")
                        .font(.body)
                    TextField("Active phone number", text: $donationVM.phone)
                        .keyboardType(.numberPad)
                        .padding(20)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 30))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(
                                    showPhoneError ? Color.red : Color.red.opacity(0.0)
                                )
                        )
                    if showPhoneError {
                        Text("*Phone number is required")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            Spacer()
            Button{
                if donationVM.name.isEmpty {
                    showNameError = true
                } else {
                    showNameError = false
                }
                if donationVM.phone.isEmpty {
                    showPhoneError = true
                } else {
                    showPhoneError = false
                }
                if !donationVM.name.isEmpty && !donationVM.phone.isEmpty {
                    onNext()
                }
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
        .onChange(of: donationVM.name) { _, newValue in
            if !newValue.isEmpty {
                showNameError = false
            }
        }.onChange(of: donationVM.phone) { _, newValue in
            if !newValue.isEmpty {
                showPhoneError = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        FormView{}
            .environment(AppRouter())
            .environment(DonationViewModel())
    }
    
}
