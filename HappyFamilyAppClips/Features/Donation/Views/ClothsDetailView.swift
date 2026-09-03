//
//  ClothsDetailView.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 03/09/26.
//

import SwiftUI

struct ClothDetailView: View {
    @Environment(DonationViewModel.self) var donationVM
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    
    let item: ClothingItem
    
    var body: some View {
        VStack(spacing: 20) {
    Image(uiImage: item.image)
        .resizable()
        .scaledToFit()
        .frame(maxHeight: 420)

    Text(item.isPassed ? "Diterima" : "Ditolak")
        .font(.title2.bold())

    Spacer()
}
.padding()
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
