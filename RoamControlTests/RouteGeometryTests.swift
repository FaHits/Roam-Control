import XCTest
@testable import RoamControl

final class RouteGeometryTests: XCTestCase {
    private let start = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)

    private var square: [GeoCoordinate] {
        [
            start,
            GeoCoordinate(latitude: 31.2304, longitude: 121.4747),
            GeoCoordinate(latitude: 31.2314, longitude: 121.4747),
            GeoCoordinate(latitude: 31.2314, longitude: 121.4737)
        ]
    }

    func testOpenRouteInterpolatesHalfwayAlongFirstSegment() throws {
        let geometry = try RouteGeometry(points: square, isClosed: false)
        let coordinate = geometry.coordinate(atDistance: geometry.segmentLengths[0] / 2)

        XCTAssertEqual(coordinate.latitude, 31.2304, accuracy: 0.000_001)
        XCTAssertEqual(coordinate.longitude, 121.4742, accuracy: 0.000_001)
    }

    func testClosedRouteAddsClosingSegment() throws {
        let geometry = try RouteGeometry(points: square, isClosed: true)

        XCTAssertTrue(geometry.isClosed)
        XCTAssertEqual(geometry.points, square + [start])
        XCTAssertEqual(geometry.segmentLengths.count, 4)
        XCTAssertEqual(
            geometry.segmentLengths.last!,
            square[3].distance(to: start),
            accuracy: 1e-9
        )
    }

    func testClosedRouteReturnsStartAtTotalDistance() throws {
        let geometry = try RouteGeometry(points: square, isClosed: true)
        let coordinate = geometry.coordinate(atDistance: geometry.totalDistance)

        XCTAssertEqual(coordinate.latitude, start.latitude, accuracy: 1e-12)
        XCTAssertEqual(coordinate.longitude, start.longitude, accuracy: 1e-12)
    }

    func testConsecutiveNearDuplicatePointsAreCollapsed() throws {
        let nearDuplicate = GeoCoordinate(
            latitude: start.latitude + 0.000_000_5,
            longitude: start.longitude
        )
        let end = GeoCoordinate(latitude: 31.2314, longitude: 121.4737)
        let geometry = try RouteGeometry(
            points: [start, nearDuplicate, end],
            isClosed: false
        )

        XCTAssertEqual(geometry.points, [start, end])
        XCTAssertEqual(geometry.segmentLengths.count, 1)
    }

    func testInvalidCoordinateThrows() {
        let invalidCoordinates = [
            GeoCoordinate(latitude: .nan, longitude: 0),
            GeoCoordinate(latitude: 0, longitude: .infinity),
            GeoCoordinate(latitude: 90.000_001, longitude: 0),
            GeoCoordinate(latitude: 0, longitude: -180.000_001)
        ]

        XCTAssertTrue(invalidCoordinates.allSatisfy { !$0.isValid })
        XCTAssertThrowsError(
            try RouteGeometry(points: [start, invalidCoordinates[0]], isClosed: false)
        ) { error in
            XCTAssertEqual(error as? RouteGeometryError, .invalidCoordinate)
        }
    }

    func testTooFewEffectivePointsThrows() {
        let second = GeoCoordinate(latitude: 31.2314, longitude: 121.4737)

        XCTAssertThrowsError(
            try RouteGeometry(points: [start, second], isClosed: true)
        ) { error in
            XCTAssertEqual(
                error as? RouteGeometryError,
                .tooFewPoints(minimum: 3)
            )
        }
        XCTAssertThrowsError(
            try RouteGeometry(points: [start], isClosed: false)
        ) { error in
            XCTAssertEqual(
                error as? RouteGeometryError,
                .tooFewPoints(minimum: 2)
            )
        }
    }

    func testZeroLengthRouteThrows() {
        let nearDuplicate = GeoCoordinate(
            latitude: start.latitude + 0.000_000_5,
            longitude: start.longitude
        )

        XCTAssertThrowsError(
            try RouteGeometry(
                points: [start, nearDuplicate, start],
                isClosed: true
            )
        ) { error in
            XCTAssertEqual(error as? RouteGeometryError, .zeroLength)
        }
    }

    func testThousandLoopReuseStaysNumericallyStable() throws {
        let geometry = try RouteGeometry(points: square, isClosed: true)
        let coordinate = geometry.coordinate(atDistance: geometry.totalDistance * 1_000)

        XCTAssertEqual(coordinate.latitude, start.latitude, accuracy: 1e-9)
        XCTAssertEqual(coordinate.longitude, start.longitude, accuracy: 1e-9)
    }

    func testDistanceClampingUsesRouteEndpoints() throws {
        let openGeometry = try RouteGeometry(points: square, isClosed: false)
        let beforeStart = openGeometry.coordinate(atDistance: -1)
        let beyondEnd = openGeometry.coordinate(atDistance: openGeometry.totalDistance + 1)

        XCTAssertEqual(beforeStart, start)
        XCTAssertEqual(beyondEnd, square.last)
    }
}
