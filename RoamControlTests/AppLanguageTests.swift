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

        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["zh-Hans"])
    }

    func testEnglishWritesEnglishIdentifier() {
        AppLanguage.english.apply(to: defaults)

        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["en"])
    }

    func testSystemRemovesOverride() {
        AppLanguage.english.apply(to: defaults)
        XCTAssertNotNil(defaults.object(forKey: "AppleLanguages"))

        AppLanguage.system.apply(to: defaults)

        XCTAssertNil(defaults.object(forKey: "AppleLanguages"))
    }
}
