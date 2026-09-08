//
//  AccessoryScan.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

extension AccessoryScanResult {
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

}
