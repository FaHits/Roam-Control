import XCTest

/// Drives the app on the `-uiTest` fixture: paired, onboarded, one route named "UI Loop".
/// Every case leaves one screenshot behind, because these checks are the only evidence the
/// window has a human-reviewable picture of the layout.
final class RoamControlUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20), "home screen did not appear")
        allowLocationIfAsked()
        XCTAssertTrue(app.buttons["Settings"].isHittable, "a system alert is still covering the home screen")
    }

    /// A fresh simulator has not answered the location prompt yet and the map asks for it on
    /// launch; that alert sits above the window and swallows every tap until it is answered.
    private func allowLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 5) else { return }

        for label in ["Allow While Using App", "使用App时允许", "Allow Once", "允许一次"] {
            let button = alert.buttons[label]
            if button.exists {
                button.tap()
                return
            }
        }
    }

    // MARK: - Search

    func testSearchSheetLayout() {
        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "search field missing")
        XCTAssertLessThanOrEqual(field.frame.height, 44, "search field is \(field.frame.height) pt tall")

        field.tap()
        let keyboard = app.keyboards.element
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "the keyboard did not appear")
        XCTAssertLessThanOrEqual(
            field.frame.maxY,
            keyboard.frame.minY,
            "the field ends at \(field.frame.maxY), the keyboard starts at \(keyboard.frame.minY)"
        )

        // The bar stays usable with the keyboard up, and the page is not locked: dismissing
        // the keyboard works while the field is editing.
        let dismiss = app.buttons["Dismiss keyboard"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5), "the search bar lost its Done button")
        XCTAssertTrue(dismiss.isHittable, "the search bar is not reachable with the keyboard up")

        attachScreenshot(named: "search-sheet.png")

        dismiss.tap()
        XCTAssertTrue(
            keyboard.waitForNonExistence(timeout: 5),
            "the keyboard did not go away, so the page below it is not interactive"
        )
    }

    // MARK: - Run card

    /// A simulator has no device session to start, so the card lands in its unavailable state.
    /// The name now says that; the assertions check this state still lays out every metric and a
    /// button big enough to press, instead of pretending a run is happening.
    func testRunCardUnavailable() {
        openRunCard()

        let card = app.descendants(matching: .any)["run.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "run card missing")

        let header = app.staticTexts["Run unavailable"]
        XCTAssertTrue(header.waitForExistence(timeout: 10), "the card is not showing the unavailable title")
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'could not start'")).firstMatch.exists,
            "the card is not saying why the run did not start"
        )

        for name in ["Speed", "Cadence", "Distance", "Elapsed"] {
            let metric = app.descendants(matching: .any)["run.metric.\(name)"]
            XCTAssertTrue(metric.waitForExistence(timeout: 10), "\(name) metric missing from the card")
            XCTAssertFalse(metric.label.isEmpty, "\(name) metric has no label")
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["run.metric.Distance"].label.contains("0 m"),
            "the unavailable card claims a distance was covered"
        )

        let primary = app.buttons["run.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10), "primary control missing")
        XCTAssertGreaterThanOrEqual(
            primary.frame.height,
            44,
            "primary control is \(primary.frame.height) pt tall"
        )

        attachScreenshot(named: "run-card-unavailable.png")
    }

    // MARK: - Route library

    func testRouteLibraryRows() {
        openRouteLibrary()

        let row = app.buttons["route.row.UI Loop"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the UI Loop row is missing")
        let label = row.label
        XCTAssertTrue(label.contains("UI Loop"), "row label is \"\(label)\"")
        XCTAssertTrue(
            label.lowercased().contains("closed") || label.contains("闭合"),
            "row label has no closed-loop marker: \"\(label)\""
        )
        guard let metres = firstMetres(in: label) else {
            return XCTFail("row label has no distance in metres: \"\(label)\"")
        }
        XCTAssertTrue((280...320).contains(metres), "row reports \(metres) m, expected about 300 m")

        attachScreenshot(named: "route-library.png")
    }

    // MARK: - Rename dialog

    func testRenameDialogLayout() {
        openRouteLibrary()

        let row = app.buttons["route.row.UI Loop"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the UI Loop row is missing")
        row.swipeLeft()

        let rename = app.buttons["Rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "swiping the row did not reveal Rename")
        rename.tap()

        let dialog = app.descendants(matching: .any)["rename.dialog"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "rename dialog missing")
        let width = dialog.frame.width
        XCTAssertTrue((260...290).contains(width), "dialog is \(width) pt wide")
        XCTAssertTrue(app.buttons["Cancel"].exists, "cancel button missing")
        XCTAssertTrue(app.buttons["Save"].exists, "save button missing")

        attachScreenshot(named: "rename-dialog.png")
    }

    // MARK: - Settings

    func testSettingsVersionRows() {
        app.buttons["Settings"].tap()

        // The About block is the last section of a lazily built list, so its rows only join the
        // accessibility tree once the list has been scrolled towards them.
        let versionElement = app.descendants(matching: .any)["settings.version"]
        for _ in 0..<3 where !versionElement.exists {
            app.swipeUp()
        }
        XCTAssertTrue(versionElement.waitForExistence(timeout: 10), "version row missing after scrolling")

        let version = text(of: "settings.version", "version row")
        XCTAssertTrue(version.contains("0.11.0"), "version row is \"\(version)\"")
        let build = text(of: "settings.build", "build row")
        XCTAssertTrue(build.contains("63"), "build row is \"\(build)\"")

        let built = text(of: "settings.built", "build time row")
        XCTAssertFalse(built.isEmpty, "build time row is empty")
        XCTAssertFalse(built.contains("Unknown"), "build time row is \"\(built)\"")
        XCTAssertFalse(built.contains("09-15"), "build time is the placeholder date: \"\(built)\"")
        XCTAssertFalse(built.contains("9月15"), "build time is the placeholder date: \"\(built)\"")

        attachScreenshot(named: "settings.png")
    }

    // MARK: - Helpers

    private func openRouteLibrary() {
        let library = app.buttons["Routes"]
        XCTAssertTrue(library.waitForExistence(timeout: 10), "route library button missing")
        library.tap()
        XCTAssertTrue(
            app.navigationBars["My Routes"].waitForExistence(timeout: 10)
                || app.staticTexts["My Routes"].waitForExistence(timeout: 2),
            "the route library sheet did not open"
        )
    }

    private func openRunCard() {
        openRouteLibrary()

        let row = app.buttons["route.row.UI Loop"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the UI Loop row is missing")
        row.tap()

        let start = app.buttons["Start Run"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "run setup did not open")
        start.tap()
    }

    /// `LabeledContent` exposes its value either as the value or as the tail of the label,
    /// depending on the row; both shapes count.
    private func text(of identifier: String, _ description: String) -> String {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(description) missing")
        let value = element.value as? String ?? ""
        return element.label + " " + value
    }

    private func firstMetres(in label: String) -> Int? {
        let parts = label.split(separator: " ")
        for (index, part) in parts.enumerated() where part == "m" && index > 0 {
            if let metres = Int(parts[index - 1]) {
                return metres
            }
            if let decimal = Double(parts[index - 1]) {
                return Int(decimal)
            }
        }
        return nil
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
