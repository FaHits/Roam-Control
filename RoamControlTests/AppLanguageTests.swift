import XCTest
@testable import RoamControl

final class AppLanguageTests: XCTestCase {
    private static let suiteName = "AppLanguageTests"
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        defaults = nil
        super.tearDown()
    }

    func testSimplifiedChineseWritesSimplifiedChineseIdentifier() {
        AppLanguage.simplifiedChinese.apply(to: defaults)

        XCTAssertEqual(storedAppleLanguages, ["zh-Hans"])
    }

    func testEnglishWritesEnglishIdentifier() {
        AppLanguage.english.apply(to: defaults)

        XCTAssertEqual(storedAppleLanguages, ["en"])
    }

    func testSystemRemovesOverride() {
        AppLanguage.english.apply(to: defaults)
        XCTAssertEqual(storedAppleLanguages, ["en"])

        AppLanguage.system.apply(to: defaults)

        XCTAssertNil(storedAppleLanguages)
    }

    func testEffectiveLanguageFollowsSystemPreferenceWhenNoOverride() {
        XCTAssertEqual(
            AppLanguage.effective(overrideIdentifiers: nil, systemIdentifiers: ["en-GB"]),
            .english
        )
        XCTAssertEqual(
            AppLanguage.effective(overrideIdentifiers: nil, systemIdentifiers: ["zh-Hans-CN"]),
            .simplifiedChinese
        )
        XCTAssertEqual(
            AppLanguage.effective(overrideIdentifiers: nil, systemIdentifiers: ["fr-FR"]),
            .system
        )
        XCTAssertEqual(
            AppLanguage.effective(overrideIdentifiers: nil, systemIdentifiers: []),
            .system
        )
    }

    func testEffectiveLanguagePrefersStoredOverride() {
        XCTAssertEqual(
            AppLanguage.effective(overrideIdentifiers: ["zh-Hans"], systemIdentifiers: ["en"]),
            .simplifiedChinese
        )
        XCTAssertEqual(
            AppLanguage.effective(overrideIdentifiers: ["en"], systemIdentifiers: ["zh-Hans"]),
            .english
        )
    }

    /// English system plus an English selection must not look like a change.
    func testEnglishSelectionUnderEnglishSystemIsNotAChange() {
        let current = AppLanguage.effective(overrideIdentifiers: nil, systemIdentifiers: ["en"])

        XCTAssertEqual(current, .english)
        XCTAssertFalse(AppLanguage.english.requiresRestart(comparedTo: current))
    }

    func testSelectingAnotherLanguageRequiresRestartAndWritesOverride() {
        let current = AppLanguage.effective(overrideIdentifiers: nil, systemIdentifiers: ["en"])

        XCTAssertTrue(AppLanguage.simplifiedChinese.requiresRestart(comparedTo: current))

        AppLanguage.simplifiedChinese.apply(to: defaults)

        XCTAssertEqual(storedAppleLanguages, ["zh-Hans"])
    }

    func testSelectingCurrentSimplifiedChineseIsNotAChange() {
        let current = AppLanguage.effective(
            overrideIdentifiers: ["zh-Hans"],
            systemIdentifiers: ["en"]
        )

        XCTAssertFalse(AppLanguage.simplifiedChinese.requiresRestart(comparedTo: current))
    }

    func testRestorationStatusMapsToNonEmptyCopy() {
        let internalStates = [
            "Not requested",
            "Stop requested; awaiting device response",
            "Stop not confirmed; real location unverified",
            "Stop command acknowledged; real location reacquisition unverified"
        ]

        for state in internalStates {
            XCTAssertFalse(ConnectionHealthView.restorationText(for: state).isEmpty, state)
        }

        XCTAssertEqual(
            ConnectionHealthView.restorationText(for: "Unexpected internal state"),
            "Unexpected internal state"
        )
    }

    /// Reads only this suite's own domain. `object(forKey:)` falls back to the
    /// system domain, which always carries an `AppleLanguages` value.
    private var storedAppleLanguages: [String]? {
        defaults.persistentDomain(forName: Self.suiteName)?["AppleLanguages"] as? [String]
    }
}
