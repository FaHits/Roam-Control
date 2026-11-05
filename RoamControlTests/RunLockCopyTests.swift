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
}
