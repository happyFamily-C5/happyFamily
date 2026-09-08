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
        VStack {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        
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
