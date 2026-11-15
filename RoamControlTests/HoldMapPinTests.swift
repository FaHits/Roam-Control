import XCTest
@testable import RoamControl

final class HoldMapPinTests: XCTestCase {
    private let coordinate = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)

    func testHoldingWithCoordinateShowsPinWithGivenName() {
        let pin = HoldMapPin.pin(isHolding: true, coordinate: coordinate, name: "People's Square")

        XCTAssertEqual(pin?.name, "People's Square")
        XCTAssertEqual(pin?.coordinate, coordinate)
    }

    func testHoldingWithoutNameFallsBackToTheHeldHereTitle() {
        // Locale-independent on purpose: the fallback is the app's localized "Held here", so the
        // expectation comes from the product's own code instead of a literal.
        let expected = HeldPointTarget.make(coordinate: coordinate, resolvedName: nil).name
        let pin = HoldMapPin.pin(isHolding: true, coordinate: coordinate, name: nil)

        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(pin?.name, expected)
    }

    func testNotHoldingShowsNoPin() {
        XCTAssertNil(HoldMapPin.pin(isHolding: false, coordinate: coordinate, name: "People's Square"))
    }

    func testHoldingWithoutCoordinateShowsNoPin() {
        XCTAssertNil(HoldMapPin.pin(isHolding: true, coordinate: nil, name: "People's Square"))
    }
}
