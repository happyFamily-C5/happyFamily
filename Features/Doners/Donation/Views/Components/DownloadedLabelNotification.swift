//
//  DownloadedLabelNotification.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 09/09/26.
//

import SwiftUI

struct DownloadedLabelNotification: View {
    var body: some View {
        ZStack {
            HStack(spacing: 4) {
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.primaryCyan)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Label telah di unduh ke galeri.")
                    .font(.subheadline)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 99))
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    DownloadedLabelNotification()
}
