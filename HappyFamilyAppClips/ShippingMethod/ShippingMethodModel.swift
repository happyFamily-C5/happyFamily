//
//  ShippingMethodModel.swift
//  HappyFamilyAppClips
//
//  Created by binc876 on 27/08/26.
//

enum ShippingMethodModel: String, CaseIterable, Identifiable {
    case direct = "Antar Langsung"
    case ojol = "Ojek Online"
    case expedition = "Ekspedisi"

    var id: String {
        rawValue
    }

    var description: String {
        switch self {
        case .direct:
            "Kamu membawa langsung paketnya ke lokasi drop-point"
        case .ojol:
            "Kamu pesan ojek, biar driver yang antar paketnya ke lokasi drop-point"
        case .expedition:
            "Kamu bawa paketnya ke ekspedisi terdekat, biar kurir yang antar paketnya ke lokasi drop-point"
        }
    }
}
