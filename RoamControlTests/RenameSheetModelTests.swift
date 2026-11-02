import XCTest

@testable import RoamControl

final class RenameSheetModelTests: XCTestCase {
    func testRenameSheetModelRejectsWhitespaceOnlyName() {
        var model = RenameSheetModel(initialName: "Morning Loop")
        model.text = " \n\t "

        XCTAssertTrue(model.trimmedName.isEmpty)
        XCTAssertFalse(model.canSubmit)
        XCTAssertNil(model.submit())
    }

    func testRenameSheetModelTrimsSurroundingWhitespace() {
        var model = RenameSheetModel(initialName: "Morning Loop")
        model.text = "  Riverside Loop\n"

        XCTAssertEqual(model.trimmedName, "Riverside Loop")
        XCTAssertEqual(model.submit(), "Riverside Loop")
    }

    func testRenameSheetModelAllowsRenamingToTheSameName() {
        let model = RenameSheetModel(initialName: "Morning Loop")

        XCTAssertTrue(model.canSubmit)
        XCTAssertEqual(model.submit(), "Morning Loop")
    }

    func testRenameSheetModelKeepsSubmittedNameWhenValid() {
        var model = RenameSheetModel(initialName: "Morning Loop")
        model.text = "Hill Repeats"

        XCTAssertEqual(model.submit(), "Hill Repeats")
        XCTAssertEqual(model.trimmedName, "Hill Repeats")
        XCTAssertEqual(model.text, "Hill Repeats")
    }
}
