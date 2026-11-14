import XCTest
@testable import RoamControl

final class MapTapPolicyTests: XCTestCase {
    func testSearchEditingWinsOverEveryLock() {
        XCTAssertEqual(
            MapTapPolicy.action(
                isSearchEditing: true,
                walkingLocksDestination: true,
                runLocksRouteInput: true
            ),
            .resignSearch
        )
    }

    func testWalkingPreviewLockIsExplainedBeforeTheRunLock() {
        XCTAssertEqual(
            MapTapPolicy.action(
                isSearchEditing: false,
                walkingLocksDestination: true,
                runLocksRouteInput: true
            ),
            .hintWalkingPreviewLocked
        )
    }

    func testRunLockIsExplained() {
        XCTAssertEqual(
            MapTapPolicy.action(
                isSearchEditing: false,
                walkingLocksDestination: false,
                runLocksRouteInput: true
            ),
            .hintRunLocked
        )
    }

    func testFreeMapTapSelectsPin() {
        XCTAssertEqual(
            MapTapPolicy.action(
                isSearchEditing: false,
                walkingLocksDestination: false,
                runLocksRouteInput: false
            ),
            .selectPin
        )
    }
}
