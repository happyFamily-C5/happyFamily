//
//  IconButton.swift
//  happyFamily
//
//  Created by Gracia Adonay Efendi on 28/08/26.
//

import SwiftUI

struct IconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .foregroundStyle(.black)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Icon Buttons") {
    HStack(spacing: 12) {
        IconButton(
            systemName: "chevron.left",
            accessibilityLabel: "Back"
        ) {
            print("Back tapped")
        }

        IconButton(
            systemName: "plus",
            accessibilityLabel: "Add"
        ) {
            print("Add tapped")
        }

        IconButton(
            systemName: "qrcode",
            accessibilityLabel: "QR Code"
        ) {
            print("QR tapped")
        }

        IconButton(
            systemName: "xmark",
            accessibilityLabel: "Close"
        ) {
            print("Close tapped")
        }
    }
    .padding()
}
