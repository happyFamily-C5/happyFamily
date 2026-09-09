//
//  ClothsDetailView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 03/09/26.
//

import SwiftUI

struct ClothDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DonationViewModel.self) var donationVM
    @State private var showDeleteAlert = false
    
    let item: ClothingItem
    
    var body: some View {
        VStack(spacing: 32) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(width: 330)
            
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text("Diterima")
                        .foregroundStyle(Color.white)
                        .font(.subheadline).bold()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Color(#colorLiteral(red: 0.4410519004, green: 0.8715734482, blue: 0.5325306058, alpha: 1)),
                    in: RoundedRectangle(cornerRadius: 24)
                )
                
                Text("Pakaian layak untuk di \ndonasikan ")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button {
                showDeleteAlert = true
            } label: {
                Text("Hapus Foto")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.red)
            .clipShape(Capsule())
            .padding(.horizontal, 24)
    
        }
        .padding(.top, 32)
        .navigationTitle("Detail Pakaian")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Hapus foto ini?", isPresented: $showDeleteAlert) {
            Button("Batal", role: .cancel) {}

            Button("Hapus", role: .destructive) {
                donationVM.clothingItems.removeAll { $0.id == item.id }
                dismiss()
            }
        } message: {
            Text("Foto ini akan dihapus dari daftar pakaian.")
        }
    }
}

#Preview {
    NavigationStack {
        ClothDetailView(
            item: ClothingItem(image: UIImage(named: "Image 3") ?? UIImage(), isPassed: true)
        )
        .environment(DonationViewModel())
        .environment(AppRouter())
    }
}
