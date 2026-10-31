import CoreLocation
import XCTest
@testable import RoamControl

final class ChinaCoordinateTransformTests: XCTestCase {
    private func assertNear(
        _ actual: CLLocationCoordinate2D,
        latitude: Double,
        longitude: Double,
        toleranceMeters: CLLocationDistance = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let distance = CLLocation(latitude: actual.latitude, longitude: actual.longitude)
            .distance(from: CLLocation(latitude: latitude, longitude: longitude))
        XCTAssertLessThan(distance, toleranceMeters, "offset \(distance) m", file: file, line: line)
    }

    private func offsetMeters(
        from latitude: Double,
        _ longitude: Double,
        to other: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    func testTiananmenMatchesKnownGCJ02() {
        let converted = ChinaCoordinateTransform.wgs84ToGCJ02(
            latitude: 39.908722,
            longitude: 116.397499
        )

        assertNear(converted, latitude: 39.91012550007891, longitude: 116.4037425752605)
    }

    func testLingnanNormalUniversityMatchesKnownGCJ02() {
        let converted = ChinaCoordinateTransform.wgs84ToGCJ02(
            latitude: 21.27122,
            longitude: 110.34213
        )

        assertNear(converted, latitude: 21.268808687690072, longitude: 110.34659102093997)
    }

    func testZhanjiangTrackMatchesKnownGCJ02AndExpectedOffset() {
        let converted = ChinaCoordinateTransform.wgs84ToGCJ02(
            latitude: 21.2585,
            longitude: 110.3025
        )

        assertNear(converted, latitude: 21.25601589175258, longitude: 110.30687415389694)

        let offset = offsetMeters(from: 21.2585, 110.3025, to: converted)
        XCTAssertGreaterThan(offset, 525)
        XCTAssertLessThan(offset, 535)
    }

    func testRoundTripStaysWithinHalfMeter() {
        let gcj = CLLocationCoordinate2D(latitude: 21.25601589175258, longitude: 110.30687415389694)
        let wgs = ChinaCoordinateTransform.gcj02ToWGS84(
            latitude: gcj.latitude,
            longitude: gcj.longitude
        )
        let restored = ChinaCoordinateTransform.wgs84ToGCJ02(
            latitude: wgs.latitude,
            longitude: wgs.longitude
        )

        assertNear(restored, latitude: gcj.latitude, longitude: gcj.longitude, toleranceMeters: 0.5)
        XCTAssertEqual(restored.latitude, gcj.latitude, accuracy: 1e-6)
        XCTAssertEqual(restored.longitude, gcj.longitude, accuracy: 1e-6)
    }

    func testOutsideChinaReturnsInputUnchanged() {
        let tokyo = ChinaCoordinateTransform.wgs84ToGCJ02(latitude: 35.681236, longitude: 139.767125)
        let london = ChinaCoordinateTransform.gcj02ToWGS84(latitude: 51.507351, longitude: -0.127758)

        XCTAssertEqual(tokyo.latitude, 35.681236)
        XCTAssertEqual(tokyo.longitude, 139.767125)
        XCTAssertEqual(london.latitude, 51.507351)
        XCTAssertEqual(london.longitude, -0.127758)
    }

    func testAdapterNonePassesThrough() {
        let adapter = DeviceCoordinateAdapter(conversion: .none)
        let coordinate = adapter.coordinate(latitude: 39.908722, longitude: 116.397499)

        XCTAssertEqual(coordinate.latitude, 39.908722)
        XCTAssertEqual(coordinate.longitude, 116.397499)
    }

    func testAdapterWGS84ToGCJ02HitsTiananmenGCJ() {
        let adapter = DeviceCoordinateAdapter(conversion: .wgs84ToGCJ02)
        let coordinate = adapter.coordinate(latitude: 39.908722, longitude: 116.397499)

        assertNear(coordinate, latitude: 39.91012550007891, longitude: 116.4037425752605)
    }

    func testAdapterGCJ02ToWGS84HitsTiananmenWGS() {
        let adapter = DeviceCoordinateAdapter(conversion: .gcj02ToWGS84)
        let coordinate = adapter.coordinate(
            latitude: 39.91012550007891,
            longitude: 116.4037425752605
        )

        assertNear(coordinate, latitude: 39.908722, longitude: 116.397499)
    }

    func testAdapterDoesNotMutateInput() {
        let target = LocationTarget(
            name: "Tiananmen",
            subtitle: "Square",
            latitude: 39.908722,
            longitude: 116.397499
        )
        let adapter = DeviceCoordinateAdapter(conversion: .wgs84ToGCJ02)
        _ = adapter.coordinate(latitude: target.latitude, longitude: target.longitude)

        XCTAssertEqual(target.latitude, 39.908722)
        XCTAssertEqual(target.longitude, 116.397499)
        XCTAssertEqual(target.coordinate.latitude, 39.908722)
        XCTAssertEqual(target.coordinate.longitude, 116.397499)
    }
}
