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

    func testSelectingDisplayedLanguageDoesNotPrompt() {
        XCTAssertFalse(
            AppLanguage.shouldPromptRestart(
                selecting: .simplifiedChinese,
                displayed: .simplifiedChinese,
                systemIdentifiers: ["zh-Hans"]
            )
        )
    }

    func testFollowingSystemWhenItMatchesDisplayedDoesNotPrompt() {
        XCTAssertFalse(
            AppLanguage.shouldPromptRestart(
                selecting: .system,
                displayed: .simplifiedChinese,
                systemIdentifiers: ["zh-Hans"]
            )
        )
    }

    func testSelectingEnglishWhileChineseDoesPrompt() {
        XCTAssertTrue(
            AppLanguage.shouldPromptRestart(
                selecting: .english,
                displayed: .simplifiedChinese,
                systemIdentifiers: ["zh-Hans"]
            )
        )
    }

    func testSelectingChineseWhileEnglishDoesPrompt() {
        XCTAssertTrue(
            AppLanguage.shouldPromptRestart(
                selecting: .simplifiedChinese,
                displayed: .english,
                systemIdentifiers: ["zh-Hans"]
            )
        )
    }

    func testFollowingChineseSystemWhileEnglishDoesPrompt() {
        XCTAssertTrue(
            AppLanguage.shouldPromptRestart(
                selecting: .system,
                displayed: .english,
                systemIdentifiers: ["zh-Hans"]
            )
        )
    }

    /// Even when no prompt is due, the choice must land in `AppleLanguages`.
    func testSystemSelectionAppliesEvenWithoutAPrompt() {
        AppLanguage.simplifiedChinese.apply(to: defaults)
        XCTAssertEqual(storedAppleLanguages, ["zh-Hans"])

        AppLanguage.system.apply(to: defaults)

        XCTAssertNil(storedAppleLanguages)
        XCTAssertFalse(
            AppLanguage.shouldPromptRestart(
                selecting: .system,
                displayed: .simplifiedChinese,
                systemIdentifiers: ["zh-Hans"]
            )
        )
    }

    func testRecordSystemLanguageWritesSnapshotWhenNotOverridden() {
        AppLanguage.recordSystemLanguageIfUnoverridden(
            defaults: defaults,
            systemIdentifiers: ["zh-Hans"]
        )

        XCTAssertEqual(
            AppLanguage.systemLanguageIdentifiers(
                defaults: defaults,
                systemIdentifiers: ["en"]
            ),
            ["zh-Hans"]
        )
    }

    func testRecordSystemLanguageKeepsSnapshotWhenOverridden() {
        AppLanguage.simplifiedChinese.apply(to: defaults)

        AppLanguage.recordSystemLanguageIfUnoverridden(
            defaults: defaults,
            systemIdentifiers: ["en"]
        )

        XCTAssertNil(defaults.object(forKey: AppLanguage.systemSnapshotKey))
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
