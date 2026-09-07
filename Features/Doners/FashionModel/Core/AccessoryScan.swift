//
//  AccessoryScan.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

struct AccessoryFinding: Identifiable, Equatable {
    let attribute: String
    let confidence: Float
    let isPresent: Bool

    var id: String {
        attribute
    }
}

struct GarmentType: Equatable {
    let name: String
    let confidence: Float
}

struct AccessoryScanResult: Equatable {
    let findings: [AccessoryFinding]
    let garmentType: GarmentType?
    let multipleGarmentsProbability: Float
    let hasMultipleGarments: Bool

    var removable: [AccessoryFinding] {
        findings.filter { $0.isPresent && AccessoryHead.removeFlagAttributes.contains($0.attribute) }
    }

    var present: [AccessoryFinding] {
        findings.filter(\.isPresent)
    }

    var grouped: [(label: String, confidence: Float)] {
        var order: [String] = []
        var best: [String: Float] = [:]
        for finding in present {
            let label = AccessoryHead.shared.displayName(for: finding.attribute)
            if best[label] == nil {
                order.append(label)
            }
            best[label] = max(best[label] ?? 0, finding.confidence)
        }
        return order.map { ($0, best[$0] ?? 0) }
    }

    var needsProcessing: Bool {
        !removable.isEmpty
    }

    static let empty = AccessoryScanResult(
        findings: [],
        garmentType: nil,
        multipleGarmentsProbability: 0,
        hasMultipleGarments: false
    )
}
