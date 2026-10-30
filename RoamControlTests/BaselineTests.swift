import XCTest
@testable import RoamControl

final class BaselineTests: XCTestCase {
    func testLocationTargetPreservesCoordinate() {
        let target = LocationTarget(
            name: "Track",
            subtitle: "Start",
            latitude: 31.2304,
            longitude: 121.4737
        )

        XCTAssertEqual(target.coordinate.latitude, 31.2304, accuracy: 0.000_001)
        XCTAssertEqual(target.coordinate.longitude, 121.4737, accuracy: 0.000_001)
    }
}
