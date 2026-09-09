@testable import happyFamily
import Testing

@Suite("Accessory scan domain")
struct HappyFamilyTests {
    @Test func accessoryScanResultClassifiesPresentAndRemovableFindings() {
        let removable = AccessoryFinding(attribute: "kancing", confidence: 0.9, isPresent: true)
        let safe = AccessoryFinding(attribute: "tag", confidence: 0.8, isPresent: true)
        let absent = AccessoryFinding(attribute: "resleting", confidence: 0.1, isPresent: false)
        let result = AccessoryScanResult(
            findings: [removable, safe, absent],
            garmentType: nil,
            multipleGarmentsProbability: 0,
            hasMultipleGarments: false
        )

        #expect(result.present == [removable, safe])
        #expect(result.removable == [removable])
        #expect(result.needsProcessing)
    }
}
