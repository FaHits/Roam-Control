import XCTest
@testable import RoamControl

final class MapSearchQueryTests: XCTestCase {
    func testNormalizedLeavesQueryUntouchedWhenOverseasDisabled() {
        let raw = "  Tokyo, Shibuya Crossing "

        XCTAssertEqual(MapSearchQuery.normalized(raw, overseas: false), raw)
    }

    func testNormalizedTakesTrailingSegmentWhenOverseasEnabled() {
        XCTAssertEqual(MapSearchQuery.normalized("Tokyo, Shibuya Crossing", overseas: true), "Shibuya Crossing")
        XCTAssertEqual(MapSearchQuery.normalized("东京，涩谷", overseas: true), "涩谷")
        XCTAssertEqual(MapSearchQuery.normalized("东京、塔", overseas: true), "塔")
        XCTAssertEqual(MapSearchQuery.normalized("东京; 塔", overseas: true), "塔")
    }

    func testNormalizedKeepsSingleTokenWhenOverseasEnabled() {
        XCTAssertEqual(MapSearchQuery.normalized("Tokyo", overseas: true), "Tokyo")
    }

    func testNormalizedDropsEmptySegments() {
        XCTAssertEqual(MapSearchQuery.normalized("Tokyo,,  ,Shibuya", overseas: true), "Shibuya")
        XCTAssertEqual(MapSearchQuery.normalized("Tokyo,,,", overseas: true), "Tokyo")
        XCTAssertEqual(MapSearchQuery.normalized(" , , ", overseas: true), "")
    }
}
