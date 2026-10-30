import XCTest
@testable import RoamControl

final class RouteRecoveryTests: XCTestCase {
    private let startLatitude = 31.2304
    private let startLongitude = 121.4737

    private var fixedTarget: LocationTarget {
        LocationTarget(name: "Home", subtitle: "Saved spot", latitude: startLatitude, longitude: startLongitude)
    }

    private var destinationTarget: LocationTarget {
        LocationTarget(
            name: "Office",
            subtitle: "Saved spot",
            latitude: startLatitude + 0.01,
            longitude: startLongitude + 0.01
        )
    }

    private let startedAt = Date(timeIntervalSinceReferenceDate: 770_000_000)
    private let updatedAt = Date(timeIntervalSinceReferenceDate: 770_000_123)

    // MARK: - Legacy payloads written by earlier releases

    private func legacyRecord(kind: String, addsDestination: Bool) throws -> Data {
        var payload: [String: Any] = [
            "kind": kind,
            "lastReportedLocation": [
                "name": fixedTarget.name,
                "subtitle": fixedTarget.subtitle,
                "latitude": fixedTarget.latitude,
                "longitude": fixedTarget.longitude,
            ],
            "startedAt": startedAt.timeIntervalSinceReferenceDate,
            "updatedAt": updatedAt.timeIntervalSinceReferenceDate,
        ]
        if addsDestination {
            payload["destination"] = [
                "name": destinationTarget.name,
                "subtitle": destinationTarget.subtitle,
                "latitude": destinationTarget.latitude,
                "longitude": destinationTarget.longitude,
            ]
            payload["walkingPaceMetresPerSecond"] = 1.4
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    private func route() -> RouteDefinition {
        RouteDefinition(
            id: UUID(uuidString: "0F5C5C8E-3E1B-4C2B-9A3D-1B7A4F0C9D21")!,
            name: "Riverside Loop",
            points: [
                GeoCoordinate(latitude: 31.2304, longitude: 121.4737),
                GeoCoordinate(latitude: 31.2304, longitude: 121.4787),
                GeoCoordinate(latitude: 31.2334, longitude: 121.4787),
                GeoCoordinate(latitude: 31.2334, longitude: 121.4737),
            ],
            isClosed: true,
            source: .drawn,
            createdAt: Date(timeIntervalSinceReferenceDate: 770_000_000),
            updatedAt: Date(timeIntervalSinceReferenceDate: 770_000_500)
        )
    }

    private var progress: RouteRunProgress {
        RouteRunProgress(distanceInLap: 120.5, completedLaps: 2, elapsedTime: 412.75)
    }

    // MARK: - Legacy decoding

    func testExistingFixedLocationRecordStillDecodes() throws {
        let decoded = try JSONDecoder().decode(SessionRecoveryRecord.self, from: legacyRecord(kind: "fixedLocation", addsDestination: false))

        XCTAssertEqual(decoded.kind, .fixedLocation)
        XCTAssertEqual(decoded.lastReportedLocation, fixedTarget)
        XCTAssertNil(decoded.destination)
        XCTAssertNil(decoded.walkingPaceMetresPerSecond)
        XCTAssertEqual(decoded.startedAt, startedAt)
        XCTAssertEqual(decoded.updatedAt, updatedAt)

        XCTAssertNil(decoded.savedRoute)
        XCTAssertNil(decoded.routeProgress)
        XCTAssertNil(decoded.runProfile)
        XCTAssertNil(decoded.runMode)
        XCTAssertFalse(decoded.isSavedRoute)
        XCTAssertFalse(decoded.isRouteSession)
    }

    func testExistingWalkingRecordStillDecodes() throws {
        let decoded = try JSONDecoder().decode(SessionRecoveryRecord.self, from: legacyRecord(kind: "walkingRoute", addsDestination: true))

        XCTAssertEqual(decoded.kind, .walkingRoute)
        XCTAssertEqual(decoded.destination, destinationTarget)
        XCTAssertEqual(decoded.walkingPaceMetresPerSecond, 1.4)
        XCTAssertTrue(decoded.isWalkingRoute)
        XCTAssertTrue(decoded.isRouteSession)
        XCTAssertFalse(decoded.isSavedRoute)

        XCTAssertNil(decoded.savedRoute)
        XCTAssertNil(decoded.routeProgress)
        XCTAssertNil(decoded.runProfile)
        XCTAssertNil(decoded.runMode)
    }

    // MARK: - Saved route payloads

    private func savedRecord(mode: RouteRunMode) -> SessionRecoveryRecord {
        SessionRecoveryRecord.savedRoute(
            route: route(),
            at: fixedTarget,
            progress: progress,
            profile: .running,
            mode: mode
        )
    }

    func testSavedRouteRecordRoundTripsSnapshotAndProgress() throws {
        for mode in [RouteRunMode.laps(3), .continuous] {
            let record = savedRecord(mode: mode)
            XCTAssertEqual(record.kind, .savedRoute)
            XCTAssertTrue(record.isSavedRoute)
            XCTAssertTrue(record.isRouteSession)
            XCTAssertNil(record.destination)
            XCTAssertNil(record.walkingPaceMetresPerSecond)
            XCTAssertEqual(record.lastReportedLocation, fixedTarget)

            let decoded = try JSONDecoder().decode(SessionRecoveryRecord.self, from: JSONEncoder().encode(record))

            XCTAssertEqual(decoded.kind, .savedRoute)
            XCTAssertTrue(decoded.isSavedRoute)
            XCTAssertTrue(decoded.isRouteSession)
            XCTAssertEqual(decoded.lastReportedLocation, fixedTarget)
            XCTAssertNil(decoded.destination)
            XCTAssertNil(decoded.walkingPaceMetresPerSecond)
            XCTAssertEqual(decoded.routeProgress, progress)
            XCTAssertEqual(decoded.runProfile, .running)
            XCTAssertEqual(decoded.runMode, mode)
            XCTAssertEqual(decoded.startedAt, record.startedAt)
            XCTAssertEqual(decoded.updatedAt, record.updatedAt)
            XCTAssertEqual(decoded, record)
        }
    }

    func testSavedRouteRecordContainsRouteGeometry() throws {
        let source = route()
        let decoded = try JSONDecoder().decode(SessionRecoveryRecord.self, from: JSONEncoder().encode(savedRecord(mode: .laps(2))))

        let stored = try XCTUnwrap(decoded.savedRoute)
        XCTAssertEqual(stored.id, source.id)
        XCTAssertEqual(stored.name, source.name)
        XCTAssertEqual(stored.points, source.points)
        XCTAssertEqual(stored.points.count, source.points.count)
        XCTAssertEqual(stored.isClosed, source.isClosed)
        XCTAssertEqual(stored.source, source.source)
        XCTAssertEqual(stored.createdAt, source.createdAt)
        XCTAssertEqual(stored.updatedAt, source.updatedAt)

        let original = try RouteGeometry(points: source.points, isClosed: source.isClosed)
        let restored = try RouteGeometry(points: stored.points, isClosed: stored.isClosed)
        XCTAssertEqual(restored.totalDistance, original.totalDistance, accuracy: 1e-9)
    }

    func testRouteModeAndProfileRemainDeterministicAfterDecoding() throws {
        let profile = RunProfile.running
        for mode in [RouteRunMode.laps(3), .continuous] {
            let decoded = try JSONDecoder().decode(SessionRecoveryRecord.self, from: JSONEncoder().encode(savedRecord(mode: mode)))

            XCTAssertEqual(decoded.runProfile, profile)
            XCTAssertEqual(try XCTUnwrap(decoded.runProfile).noiseSeed, profile.noiseSeed)
            XCTAssertEqual(decoded.runMode, mode)
            XCTAssertEqual(try XCTUnwrap(decoded.runMode).validated(), mode)
        }
    }

    func testFixedFactoryKeepsLegacyShape() throws {
        let record = SessionRecoveryRecord.fixed(at: fixedTarget)
        XCTAssertEqual(record.kind, .fixedLocation)
        XCTAssertNil(record.savedRoute)
        XCTAssertNil(record.routeProgress)
        XCTAssertFalse(record.isRouteSession)

        let decoded = try JSONDecoder().decode(SessionRecoveryRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded, record)
    }
}
