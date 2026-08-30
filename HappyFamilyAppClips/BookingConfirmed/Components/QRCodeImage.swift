//
//  QRCodeImage.swift
//  Recap
//
//  Created by Calzy Akmal Indyramdhani on 28/08/26.
//

import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeImage: View {
    let content: String

    var body: some View {
        if let qrCode = QRCode.image(from: content) {
            Image(uiImage: qrCode)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Text("Gagal membuat QR Code")
                .font(.caption2)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }
}

enum QRCode {
    private static let context = CIContext()

    static func image(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else { return nil }
        
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = outputImage
        colorFilter.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        colorFilter.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let coloredImage = colorFilter.outputImage,
              let cgImage = context.createCGImage(coloredImage, from: coloredImage.extent)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeImage(content: "Hello World")
        .frame(width: 200, height: 200)
}
