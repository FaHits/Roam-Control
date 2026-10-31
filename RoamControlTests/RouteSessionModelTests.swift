import XCTest
@testable import RoamControl

@MainActor
final class RouteSessionModelTests: XCTestCase {
    private let start = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)

    private var closedRoute: RouteDefinition {
        RouteDefinition(
            id: UUID(uuidString: "9A1E6C55-6B47-4F0E-8E1B-2C9D0A7F4411")!,
            name: "Riverside Loop",
            points: [
                start,
                GeoCoordinate(latitude: 31.2304, longitude: 121.4787),
                GeoCoordinate(latitude: 31.2334, longitude: 121.4787),
                GeoCoordinate(latitude: 31.2334, longitude: 121.4737),
            ],
            isClosed: true,
            source: .drawn,
            createdAt: Date(timeIntervalSinceReferenceDate: 770_000_000),
            updatedAt: Date(timeIntervalSinceReferenceDate: 770_000_000)
        )
    }

    private func steadyProfile(speed: Double = 2.0) -> RunProfile {
        RunProfile(
            targetSpeedMetersPerSecond: speed,
            targetCadenceStepsPerMinute: 170,
            speedVariationFraction: 0,
            cadenceVariationFraction: 0,
            gpsJitterRadiusMeters: 0,
            noiseSeed: 42
        )
    }

    private func makeAppModel() -> AppModel {
        let suiteName = "RouteSessionModelTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        preferences.removePersistentDomain(forName: suiteName)
        return AppModel(pairingService: StubPairingService(), preferences: preferences)
    }

    func testPrepareRejectsInvalidModeBeforeDeviceCall() throws {
        let appModel = makeAppModel()
        let model = RouteSessionModel()

        XCTAssertThrowsError(
            try model.prepare(
                route: closedRoute,
                profile: steadyProfile(),
                mode: .laps(0),
                progress: RouteRunProgress(distanceInLap: 0, completedLaps: 0, elapsedTime: 0)
            )
        ) { error in
            XCTAssertEqual(error as? RouteRunModeError, .invalidLapCount)
        }

        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.snapshot)
        XCTAssertNil(model.route)
        XCTAssertFalse(model.locksRouteInput)
        XCTAssertEqual(appModel.deviceSession.phase, .idle)
    }

    func testPrepareBuildsSnapshotAtSuppliedProgress() throws {
        let route = closedRoute
        let geometry = try RouteGeometry(points: route.points, isClosed: route.isClosed)
        let progress = RouteRunProgress(distanceInLap: 100, completedLaps: 2, elapsedTime: 45)
        let model = RouteSessionModel()

        try model.prepare(route: route, profile: steadyProfile(), mode: .continuous, progress: progress)

        let snapshot = try XCTUnwrap(model.snapshot)
        XCTAssertEqual(snapshot.distanceInLap, 100, accuracy: 1e-9)
        XCTAssertEqual(snapshot.completedLaps, 2)
        XCTAssertEqual(snapshot.elapsedTime, 45, accuracy: 1e-9)
        XCTAssertEqual(snapshot.totalDistance, 2 * geometry.totalDistance + 100, accuracy: 1e-6)
        XCTAssertEqual(snapshot.groundCoordinate, geometry.coordinate(atDistance: 100))
        XCTAssertEqual(snapshot.phase, .idle)

        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.completedLaps, 2)
        XCTAssertEqual(model.totalDistance, snapshot.totalDistance, accuracy: 1e-9)
        XCTAssertEqual(model.lapProgress, 100 / geometry.totalDistance, accuracy: 1e-9)
        XCTAssertEqual(model.route?.id, route.id)
        XCTAssertNil(model.errorMessage)
    }

    func testPrepareRejectsNegativeProgress() throws {
        let invalidProgress: [RouteRunProgress] = [
            RouteRunProgress(distanceInLap: -1, completedLaps: 0, elapsedTime: 0),
            RouteRunProgress(distanceInLap: 0, completedLaps: -1, elapsedTime: 0),
            RouteRunProgress(distanceInLap: 0, completedLaps: 0, elapsedTime: -1),
        ]

        for progress in invalidProgress {
            let model = RouteSessionModel()
            XCTAssertThrowsError(
                try model.prepare(route: closedRoute, profile: steadyProfile(), mode: .once, progress: progress)
            ) { error in
                XCTAssertEqual(error as? RouteSessionError, .invalidProgress, "progress \(progress) must be rejected")
            }
            XCTAssertNil(model.snapshot)
            XCTAssertEqual(model.phase, .idle)
        }
    }
    private var openRoute: RouteDefinition {
        RouteDefinition(
            id: UUID(uuidString: "3C7B1A20-5D6E-4F81-9A2B-7C4D1E0F2255")!,
            name: "Riverside Out and Back",
            points: Array(closedRoute.points.prefix(3)),
            isClosed: false,
            source: .drawn,
            createdAt: Date(timeIntervalSinceReferenceDate: 770_000_000),
            updatedAt: Date(timeIntervalSinceReferenceDate: 770_000_000)
        )
    }

    func testTripCountAndIndexFollowCompletedTrips() throws {
        let expectedIndex = [1, 2, 3, 3]
        for completedLaps in 0..<expectedIndex.count {
            let model = RouteSessionModel()
            try model.prepare(
                route: openRoute,
                profile: steadyProfile(),
                mode: .outAndBack(trips: 3),
                progress: RouteRunProgress(
                    distanceInLap: 0,
                    completedLaps: completedLaps,
                    elapsedTime: 0
                )
            )

            XCTAssertEqual(model.tripCount, 3)
            // The last trip is held once the run finished instead of counting past it.
            XCTAssertEqual(model.tripIndex, expectedIndex[completedLaps])
        }

        let loop = RouteSessionModel()
        try loop.prepare(
            route: closedRoute,
            profile: steadyProfile(),
            mode: .once,
            progress: RouteRunProgress(distanceInLap: 0, completedLaps: 0, elapsedTime: 0)
        )
        XCTAssertNil(loop.tripCount)
        XCTAssertNil(loop.tripIndex)
    }
}

private struct StubPairingService: PairingService {
    func storedRecord() async throws -> PairingRecordSummary? { nil }
    func importRecord(from url: URL) async throws -> PairingRecordSummary { throw PairingServiceError.corruptStoredRecord }
    func storeGeneratedRecord(_ data: Data, hostAltIRK: Data?) async throws -> PairingRecordSummary {
        throw PairingServiceError.corruptStoredRecord
    }
    func pairingRecordData() async throws -> Data? { nil }
    func removeRecord() async throws {}
}
