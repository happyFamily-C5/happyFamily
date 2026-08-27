//
//  ShippingMethodModel.swift
//  HappyFamilyAppClips
//
//  Created by binc876 on 27/08/26.
//

import Foundation

enum ShippingMethodModel: String, CaseIterable, Identifiable {
    case direct = "Antar Langsung"
    case ojol = "Ojek Online"
    case expedition = "Ekspedisi"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .direct:
            return "Kamu membawa langsung paketnya ke lokasi drop-point"
        case .ojol:
            return "Kamu pesan ojek, biar driver yang antar paketnya ke lokasi drop-point"
        case .expedition:
            return "Kamu bawa paketnya ke ekspedisi terdekat, biar kurir yang antar paketnya ke lokasi drop-point"
        }
    }
}
