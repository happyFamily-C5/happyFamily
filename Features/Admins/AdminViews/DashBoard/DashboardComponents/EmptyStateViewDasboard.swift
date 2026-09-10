//
//  EmptyStateViewDasboard.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 31/08/26.
import SwiftUI

struct EmptyStateViewDashboard: View {
    var onActionButtonTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
           
            Image("emptyViewHome")
                .resizable()
                .scaledToFit()
                .frame(width: 300)
            
            VStack(spacing: 8) {
                // 2. Judul Utama
                Text("Buat Event,\nKurangi Limbah tekstil")
                    .font(.title).bold()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineSpacing(4) 
                
                // 3. Subteks Deskripsi
                Text("Kumpulkan limbah tekstil bersama-sama di drop point pilihanmu dan ajak orang-orang mengumpulkan tekstil bekas ke drop point yang tersedia.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // 4. Memanggil PrimaryButton yang sudah kita buat sebelumnya
            PrimaryButton(title: "Mulai Membuat Event", action: onActionButtonTapped)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    EmptyStateViewDashboard {
        print("Tombol mulai event diklik!")
    }
    .frame(width: 393, height: 700)
}
