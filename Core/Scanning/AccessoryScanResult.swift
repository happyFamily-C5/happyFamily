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
    private static let removableAttributes: Set<String> = [
        "kancing", "resleting", "logam", "ornamen", "saku",
    ]

    let findings: [AccessoryFinding]
    let garmentType: GarmentType?
    let multipleGarmentsProbability: Float
    let hasMultipleGarments: Bool

    var removable: [AccessoryFinding] {
        findings.filter { $0.isPresent && Self.removableAttributes.contains($0.attribute) }
    }

    var present: [AccessoryFinding] {
        findings.filter(\.isPresent)
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
