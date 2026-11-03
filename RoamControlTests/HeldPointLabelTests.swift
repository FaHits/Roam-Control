import XCTest
@testable import RoamControl

final class HeldPointLabelTests: XCTestCase {
    func testHeldLabelPrefersResolvedName() {
        XCTAssertEqual(
            HeldPointLabel.title(resolvedName: "Shibuya Crossing"),
            "Shibuya Crossing"
        )
    }

    func testHeldLabelFallsBackToHeldHere() {
        XCTAssertEqual(HeldPointLabel.title(resolvedName: nil), "Held here")
        XCTAssertEqual(HeldPointLabel.title(resolvedName: "   "), "Held here")
    }
}
