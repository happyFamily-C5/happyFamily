//
//  AccessoryHead.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import Foundation

struct AccessoryHead: Decodable {
    /// Some attributes OR several sub-heads together (e.g. `resleting`: box / zip-up / fly).
    struct SubHead: Decodable {
        let weights: [Float]
        let bias: Float
        let thresholds: [String: Float]
    }

    /// Multi-class, unlike the accessory heads — a garment is exactly one type.
    struct TypeHead: Decodable {
        let classes: [String]
        let unknownClass: String
        let threshold: Float
        let mean: [Float]
        let std: [Float]
        let weights: [[Float]]
        let bias: [Float]
    }

    /// Rejects photos containing more than one garment — accessory and type accuracy
    /// drop sharply when several garments share the frame.
    struct CountHead: Decodable {
        let mean: [Float]
        let std: [Float]
        let weights: [Float]
        let bias: Float
        let threshold: Float
    }

    let version: Int
    /// Images must be resized to this before FeaturePrint — scores drift with source resolution otherwise.
    let canonicalLongestSide: Int
    let attributes: [String]
    let mean: [Float]
    let std: [Float]
    let subHeads: [String: [SubHead]]
    /// Attributes shown under one merged label (e.g. logam+ornamen). Merging is display-only —
    /// a single trained head for both scored worse than two.
    let displayGroups: [String: String]
    let sensitivityLevels: [String]
    let defaultSensitivity: String
    let typeHead: TypeHead
    let countHead: CountHead

    static let shared: AccessoryHead = {
        guard let url = Bundle.main.url(forResource: "accessory_head", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let head = try? JSONDecoder().decode(AccessoryHead.self, from: data)
        else { fatalError("accessory_head.json tidak ada di bundle atau formatnya berubah") }
        return head
    }()

    private func score(_ normalized: [Float], _ weights: [Float], _ bias: Float) -> Float {
        var total = bias
        for i in 0 ..< normalized.count {
            total += normalized[i] * weights[i]
        }
        return total
    }

    private func normalize(_ vector: [Float], mean: [Float], std: [Float]) -> [Float] {
        var out = [Float](repeating: 0, count: vector.count)
        for i in 0 ..< vector.count {
            out[i] = (vector[i] - mean[i]) / std[i]
        }
        return out
    }

    func displayName(for attribute: String) -> String {
        displayGroups[attribute] ?? attribute
    }

    func multipleGarmentsProbability(whole: [Float]) -> Float {
        let normalized = normalize(whole, mean: countHead.mean, std: countHead.std)
        return 1 / (1 + exp(-score(normalized, countHead.weights, countHead.bias)))
    }

    func evaluate(whole: [Float], sensitivity: String) -> AccessoryScanResult {
        precondition(
            whole.count == mean.count,
            "dimensi FeaturePrint \(whole.count) != \(mean.count) — revision Vision-nya beda?"
        )
        let normalizedWhole = normalize(whole, mean: mean, std: std)

        let findings = attributes.map { attribute -> AccessoryFinding in
            let heads = subHeads[attribute] ?? []
            // Confidence comes from the sub-head furthest past its own threshold, not raw score —
            // sub-heads have different scales, so raw scores aren't comparable across them.
            var present = false
            var bestMargin = -Float.greatestFiniteMagnitude
            var bestConfidence: Float = 0
            for head in heads {
                guard let threshold = head.thresholds[sensitivity] else { continue }
                let raw = score(normalizedWhole, head.weights, head.bias)
                if raw >= threshold {
                    present = true
                }
                let margin = raw - threshold
                if margin > bestMargin {
                    bestMargin = margin
                    bestConfidence = 1 / (1 + exp(-raw))
                }
            }
            return AccessoryFinding(
                attribute: attribute,
                confidence: bestConfidence,
                isPresent: present
            )
        }
        let multiProbability = multipleGarmentsProbability(whole: whole)
        return AccessoryScanResult(
            findings: findings,
            garmentType: garmentType(whole: whole),
            multipleGarmentsProbability: multiProbability,
            hasMultipleGarments: multiProbability >= countHead.threshold
        )
    }

    /// nil when the top class is "unknown" or below threshold — better to say nothing than guess.
    private func garmentType(whole: [Float]) -> GarmentType? {
        let normalized = normalize(whole, mean: typeHead.mean, std: typeHead.std)
        let logits = typeHead.classes.indices.map {
            score(normalized, typeHead.weights[$0], typeHead.bias[$0])
        }
        let maxLogit = logits.max() ?? 0
        let exps = logits.map { exp($0 - maxLogit) }
        let sum = exps.reduce(0, +)
        guard let best = exps.indices.max(by: { exps[$0] < exps[$1] }) else { return nil }
        let probability = exps[best] / sum
        let name = typeHead.classes[best]
        guard name != typeHead.unknownClass, probability >= typeHead.threshold else { return nil }
        return GarmentType(name: name, confidence: probability)
    }
}
