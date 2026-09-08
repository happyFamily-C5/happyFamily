//
//  ScanResultView.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 27/08/26.
//

import SwiftUI

/// The backdrop behind the result sheet: the still frame, dimmed, with a way out.
/// `ScanView` owns the sheet itself so it gets real detents and a real drag.
struct ClothingScanResultView: View {
    let photo: UIImage?
    var onClose: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            HStack {
                CircleIconButton(systemImage: "xmark", action: onClose)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var backdrop: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.62)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(Color.black.opacity(0.22))
        .ignoresSafeArea()
    }
}

#Preview {
    ClothingScanResultView(photo: nil)
}
