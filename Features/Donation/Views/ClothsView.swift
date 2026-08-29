//
//  ScanView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI

struct ClothsView: View {
    
    @Environment(AppRouter.self) var router
    @State private var donationVM = DonationViewModel()
    let onNext: () -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        if donationVM.clothingItems.isEmpty {
            VStack {
                Spacer()
                Image("image 1")
                    .resizable()
                    .scaledToFit()
                Button {
                    onNext()
                } label: {
                    Text("Lanjut")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(Color(red: 0.35, green: 0.5, blue: 0.4))
                .clipShape(Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .disabled(!donationVM.canProceedFromReview)
                
                Spacer()
            }
            .padding(20)
        }
        else{
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(donationVM.clothingItems) { item in
                            ClothingCard(item: item)
                        }
                        
                        AddClothingCard {
                            router.push(to: .openCamera)
                        }
                    }
                    .padding(20)
                }
                
                Button {
                    onNext()
                } label: {
                    Text("Lanjut")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(Color(red: 0.35, green: 0.5, blue: 0.4))
                .clipShape(Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .disabled(!donationVM.canProceedFromReview)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ClothsView{}
            .environment(AppRouter())
    }
    
}
