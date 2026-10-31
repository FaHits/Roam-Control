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

    /// Reads only this suite's own domain. `object(forKey:)` falls back to the
    /// system domain, which always carries an `AppleLanguages` value.
    private var storedAppleLanguages: [String]? {
        defaults.persistentDomain(forName: Self.suiteName)?["AppleLanguages"] as? [String]
    }
}
