//
//  FeaturePrintScanner.swift
//  happyFamily
//
//  Created by Calzy Akmal Indyramdhani on 26/08/26.
//

import Foundation
import Vision

struct FeaturePrintScanner {
    /// Pinned: the trained weights assume this exact revision's embedding.
    static let featurePrintRevision = VNGenerateImageFeaturePrintRequestRevision2

    private let head: AccessoryHead

    init(head: AccessoryHead = .shared) {
        self.head = head
    }

    func scan(_ image: CGImage, sensitivity: String) throws -> AccessoryScanResult {
        try head.evaluate(whole: featurePrint(of: image), sensitivity: sensitivity)
    }

    private func featurePrint(of image: CGImage) throws -> [Float] {
        let input = resized(image, longestSide: head.canonicalLongestSide) ?? image
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = Self.featurePrintRevision
        try VNImageRequestHandler(cgImage: input).perform([request])
        guard let observation = request.results?.first else { return [] }
        var vector = [Float](repeating: 0, count: observation.elementCount)
        observation.data.withUnsafeBytes { raw in
            let pointer = raw.bindMemory(to: Float.self)
            for i in 0 ..< observation.elementCount {
                vector[i] = pointer[i]
            }
        }
        return vector
    }

    private func resized(_ image: CGImage, longestSide: Int) -> CGImage? {
        let scale = Double(longestSide) / Double(max(image.width, image.height))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
