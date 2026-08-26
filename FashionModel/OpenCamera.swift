//
//  OpenCamera.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import SwiftUI

struct OpenCamera: View {
    @State private var isScanning: Bool = false

    var body: some View {
        VStack {
            Text("Ambil Gambar Baju Anda!")
                .font(.title2)
                .fontWeight(.semibold)

            Button {
                isScanning = true
            } label: {
                Text("Ambil gambar")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: 220, maxHeight: 32)
                    .padding(.vertical, 14)
            }
            .glassEffect(.regular.tint(.green), in: .capsule)
        }
        .navigationDestination(isPresented: $isScanning) {
            ScanView()
        }
    }
}

#Preview {
    OpenCamera()
}
