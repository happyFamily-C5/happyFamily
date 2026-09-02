//
//  DonationViewModel.swift
//  happyFamily
//
//  Created by Muhamad Yuan Sastro Dimianta on 27/08/26.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

enum ShippingMethod: String, CaseIterable, Identifiable {
    case direct = "Antar Langsung"
    case ojekOnline = "Ojek Online"
    case expedition = "Ekspedisi"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .direct:
            return "Kamu membawa langsung paketnya ke lokasi drop-point"
        case .ojekOnline:
            return "Kamu pesan ojek, biar driver yang antar paketnya ke lokasi drop-point"
        case .expedition:
            return "Kamu bawa paketnya ke ekspedisi terdekat, biar kurir yang antar paketnya ke lokasi drop-point"
        }
    }
}


@Observable
public class DonationViewModel {
    var name: String = ""
    var phone: String = ""
    var agreedToTerms: Bool = false
    
    let bookingID: String = UUID().uuidString
    
    
    var clothingItems: [ClothingItem] = [
//        ClothingItem(image: UIImage(named: "Image 3") ?? UIImage(), isPassed: true)
    ]
    
    var displayBookingID: String {
        String(bookingID.prefix(8)).uppercased()
    }
    
    // MARK: - Validasi tiap step
    var canProceedFromPersonalInfo: Bool {
        !name.isEmpty && !phone.isEmpty && agreedToTerms
    }
    
    var canProceedFromCapture: Bool {
        !clothingItems.isEmpty
    }
    
    var canProceedFromReview: Bool {
        clothingItems.contains { $0.isPassed == true }
    }
    
    var selectedShippingMethod: ShippingMethod? = .none

    var canProceedFromShipping: Bool {
        selectedShippingMethod != nil
    }
}

func generateQRCode(from string: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    
    if let outputImage = filter.outputImage {
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    return UIImage(systemName: "xmark") ?? UIImage()
}
