import XCTest
@testable import RoamControl

final class HeldPointLabelTests: XCTestCase {
    func testHeldLabelPrefersResolvedName() {
        XCTAssertEqual(
            HeldPointLabel.title(resolvedName: "Shibuya Crossing", fallback: "Fallback"),
            "Shibuya Crossing"
        )
    }

    func testHeldLabelFallsBackToTheCallersLabel() {
        XCTAssertEqual(HeldPointLabel.title(resolvedName: nil, fallback: "Fallback"), "Fallback")
        XCTAssertEqual(HeldPointLabel.title(resolvedName: "   ", fallback: "Fallback"), "Fallback")
    }

    func testHeldLabelTreatsAnEmptyNameAsMissing() {
        XCTAssertEqual(HeldPointLabel.title(resolvedName: "", fallback: "Fallback"), "Fallback")
    }
}
