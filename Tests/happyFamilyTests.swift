@testable import happyFamily
import XCTest

final class HappyFamilyTests: XCTestCase {
    func testAccessoryScanResultClassifiesPresentAndRemovableFindings() {
        let removable = AccessoryFinding(attribute: "kancing", confidence: 0.9, isPresent: true)
        let safe = AccessoryFinding(attribute: "tag", confidence: 0.8, isPresent: true)
        let absent = AccessoryFinding(attribute: "resleting", confidence: 0.1, isPresent: false)
        let result = AccessoryScanResult(
            findings: [removable, safe, absent],
            garmentType: nil,
            multipleGarmentsProbability: 0,
            hasMultipleGarments: false
        )

        XCTAssertEqual(result.present, [removable, safe])
        XCTAssertEqual(result.removable, [removable])
        XCTAssertTrue(result.needsProcessing)
    }
}
