//
//  ClothsView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI

struct ClothsView: View {
    @Environment(AppRouter.self) var router
    @Environment(DonationViewModel.self) var donationVM

    @State var showGuide = false

    let onNext: () -> Void

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        if donationVM.clothingItems.isEmpty {
            VStack {
                Spacer()
                Image("image 1")
                    .resizable()
                    .scaledToFit()

                Button {
//                    router.push(to: .openCamera)
                    showGuide = true
                } label: {
                    Text("Ambil Gambar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(AppColor.primaryCyan)
                .clipShape(Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                Spacer()
            }
            .padding(20)
            .sheet(isPresented: $showGuide, content: {
                ScanningInstructionPage()
                    .background(Color.white)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            })
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if router.currentStep > 1 {
                            router.currentStep -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 28) {
                Text("Tambahkan Foto Pakaian yang Kamu Donasikan")
                    .font(.title).bold()

                MaxDonationCard(maxCapacity: 5)

                ScrollView {
                    VStack(spacing: 24) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(donationVM.clothingItems) { item in
                                ClothingCard(item: item) {
                                    router.openClothDetail(for: item)
                                }
                            }
                        }
                        AddClothingCard {
                            router.push(to: .openCamera)
                        }
                    }
                }

                Button {
                    onNext()
                    //                router.push(to: .scan)
                } label: {
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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if router.currentStep > 1 {
                            router.currentStep -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ClothsView {}
            .environment(AppRouter())
            .environment(DonationViewModel())
    }
}
