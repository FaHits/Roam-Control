import XCTest
@testable import RoamControl

final class RunLockCopyTests: XCTestCase {
    func testListFooterHiddenWhenUnlocked() {
        XCTAssertNil(RunLockCopy.listFooter(isLocked: false))
    }

    func testListFooterShownWhenLocked() {
        XCTAssertEqual(
            RunLockCopy.listFooter(isLocked: true),
            LocalizedStringResource("Finish or hold the run before changing saved places.")
        )
    }

    func testSearchPlaceholderDefaultsWhenUnlocked() {
        XCTAssertEqual(
            RunLockCopy.searchPlaceholder(isLocked: false),
            LocalizedStringResource("Search places or coordinates")
        )
    }

    func testSearchPlaceholderChangesWhenLocked() {
        XCTAssertEqual(
            RunLockCopy.searchPlaceholder(isLocked: true),
            LocalizedStringResource("Finish or hold the run to search places")
        )
    }

    func testMapTapHintExplainsEachLock() {
        XCTAssertEqual(
            RunLockCopy.mapTapHint(for: .hintRunLocked),
            LocalizedStringResource("Finish this run before picking a point on the map.")
        )
        XCTAssertEqual(
            RunLockCopy.mapTapHint(for: .hintWalkingPreviewLocked),
            LocalizedStringResource("Finish the walking preview before picking a point on the map.")
        )
    }

    func testMapTapHintStaysQuietWhenTheTapIsAllowed() {
        XCTAssertNil(RunLockCopy.mapTapHint(for: .selectPin))
        XCTAssertNil(RunLockCopy.mapTapHint(for: .resignSearch))
    }
}
