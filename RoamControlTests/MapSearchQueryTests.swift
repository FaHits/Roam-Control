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

    func testCommittedHidesTextWhileComposing() {
        XCTAssertNil(MapSearchQuery.committed("dong", marked: true))
        XCTAssertNil(MapSearchQuery.committed("", marked: true))
    }

    func testCommittedPassesTextOnceCompositionEnds() {
        XCTAssertEqual(MapSearchQuery.committed("Tokyo haneda airport", marked: false), "Tokyo haneda airport")
        XCTAssertEqual(MapSearchQuery.committed("  Tokyo  ", marked: false), "  Tokyo  ")
    }

    func testCommittedPassesClearedField() {
        XCTAssertEqual(MapSearchQuery.committed("", marked: false), "")
    }

    func testOverseasSearchKeepsQueryIntactWhenComposing() {
        var query = "Tokyo"

        // Nothing is written back while the input method is composing.
        if let composing = MapSearchQuery.committed("Tokyo haneda airport", marked: true) {
            query = MapSearchQuery.normalized(composing, overseas: true)
        }
        XCTAssertEqual(query, "Tokyo")

        // Once composition ends, the overseas normalization takes the last segment.
        if let committed = MapSearchQuery.committed("Tokyo, haneda airport", marked: false) {
            query = MapSearchQuery.normalized(committed, overseas: true)
        }
        XCTAssertEqual(query, "haneda airport")
    }
}
