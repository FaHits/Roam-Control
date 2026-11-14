import XCTest
@testable import RoamControl

final class HeldPointTargetTests: XCTestCase {
    private let coordinate = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)

    func testPointTargetHasNoRouteSubtitle() {
        let target = HeldPointTarget.make(coordinate: coordinate, resolvedName: "Riverside Loop")

        XCTAssertEqual(target.name, "Riverside Loop")
        XCTAssertTrue(target.subtitle.isEmpty)
    }

    func testResolvedNameWinsAndBlankFallsBack() {
        let resolved = HeldPointTarget.make(coordinate: coordinate, resolvedName: "People's Square")
        XCTAssertEqual(resolved.name, "People's Square")

        // Locale-independent on purpose: the fallback text is the app's localized "Held here", so
        // the test compares the blank cases against the nil case instead of a literal.
        let fallback = HeldPointTarget.make(coordinate: coordinate, resolvedName: nil)
        XCTAssertFalse(fallback.name.isEmpty)
        XCTAssertNotEqual(fallback.name, "Riverside Loop")
        XCTAssertEqual(HeldPointTarget.make(coordinate: coordinate, resolvedName: "   ").name, fallback.name)
        XCTAssertEqual(HeldPointTarget.make(coordinate: coordinate, resolvedName: "").name, fallback.name)
    }

    func testCoordinatesArePreserved() {
        let target = HeldPointTarget.make(coordinate: coordinate, resolvedName: "People's Square")

        XCTAssertEqual(target.latitude, coordinate.latitude)
        XCTAssertEqual(target.longitude, coordinate.longitude)
        XCTAssertEqual(target.coordinate.latitude, coordinate.latitude)
        XCTAssertEqual(target.coordinate.longitude, coordinate.longitude)
    }
}
