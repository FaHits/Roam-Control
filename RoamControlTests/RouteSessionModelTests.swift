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

    // MARK: - Holding a run

    private var zeroProgress: RouteRunProgress {
        RouteRunProgress(distanceInLap: 0, completedLaps: 0, elapsedTime: 0)
    }

    func testHoldFromRunningFreezesProgress() throws {
        let appModel = makeAppModel()
        let model = RouteSessionModel()
        try model.prepare(route: closedRoute, profile: steadyProfile(), mode: .laps(3), progress: zeroProgress)
        model.debugBeginRunning()
        let advanced = try XCTUnwrap(model.debugTick(delta: 120))
        XCTAssertGreaterThan(advanced.distanceInLap, 0)

        model.hold(using: appModel)

        XCTAssertEqual(model.phase, .holding(.paused))
        XCTAssertEqual(model.holdOrigin, .paused)
        XCTAssertTrue(model.locksRouteInput)
        XCTAssertEqual(try XCTUnwrap(model.snapshot).distanceInLap, advanced.distanceInLap, accuracy: 1e-9)
        // A held run does not advance: the tick is rejected and the snapshot stays put.
        XCTAssertNil(model.debugTick(delta: 120))
        XCTAssertEqual(try XCTUnwrap(model.snapshot).distanceInLap, advanced.distanceInLap, accuracy: 1e-9)

        // Holding keeps the injected coordinate and the session: nothing was stopped or reopened.
        XCTAssertEqual(appModel.deviceSession.phase, .idle)
        XCTAssertEqual(appModel.debugRouteSessionStartCount, 0)
        let recovery = try XCTUnwrap(appModel.debugActiveSessionRecovery)
        XCTAssertEqual(recovery.kind, .savedRoute)
        XCTAssertTrue(recovery.wasHolding)
        XCTAssertEqual(recovery.runMode, .laps(3))
        XCTAssertEqual(try XCTUnwrap(recovery.routeProgress).distanceInLap, advanced.distanceInLap, accuracy: 1e-9)
    }

    func testHoldFromPausedKeepsPausedOrigin() throws {
        let appModel = makeAppModel()
        let model = RouteSessionModel()
        try model.prepare(route: closedRoute, profile: steadyProfile(), mode: .laps(3), progress: zeroProgress)
        model.debugBeginRunning()
        let advanced = try XCTUnwrap(model.debugTick(delta: 60))
        model.togglePause()
        XCTAssertEqual(model.phase, .paused)

        model.hold(using: appModel)

        XCTAssertEqual(model.phase, .holding(.paused))
        XCTAssertEqual(model.holdOrigin, .paused)
        XCTAssertEqual(try XCTUnwrap(model.snapshot).distanceInLap, advanced.distanceInLap, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(model.snapshot).elapsedTime, advanced.elapsedTime, accuracy: 1e-9)
        XCTAssertEqual(model.completedLaps, 0)
        XCTAssertEqual(appModel.debugRouteSessionStartCount, 0)
        XCTAssertTrue(try XCTUnwrap(appModel.debugActiveSessionRecovery).wasHolding)
    }

    func testResumeFromHoldContinuesSameLap() throws {
        let appModel = makeAppModel()
        let model = RouteSessionModel()
        let progress = RouteRunProgress(distanceInLap: 200, completedLaps: 1, elapsedTime: 30)
        try model.prepare(route: closedRoute, profile: steadyProfile(), mode: .laps(3), progress: progress)
        model.debugBeginRunning()
        let before = try XCTUnwrap(model.snapshot)
        model.hold(using: appModel)
        XCTAssertEqual(model.phase, .holding(.paused))

        model.resumeFromHold(using: appModel)

        XCTAssertEqual(model.phase, .running)
        let resumed = try XCTUnwrap(model.snapshot)
        // Same runner, same lap: the distance is neither reset nor restarted.
        XCTAssertEqual(resumed.distanceInLap, 200, accuracy: 1e-9)
        XCTAssertEqual(resumed.completedLaps, 1)
        XCTAssertEqual(resumed.totalDistance, before.totalDistance, accuracy: 1e-9)
        XCTAssertEqual(resumed.elapsedTime, 30, accuracy: 1e-9)

        let next = try XCTUnwrap(model.debugTick(delta: 10))
        XCTAssertEqual(next.distanceInLap, 220, accuracy: 1e-6)
        XCTAssertEqual(next.completedLaps, 1)
        XCTAssertEqual(model.completedLaps, 1)
        XCTAssertFalse(try XCTUnwrap(appModel.debugActiveSessionRecovery).wasHolding)
        XCTAssertEqual(appModel.debugRouteSessionStartCount, 0)
    }

    // MARK: - Continuing a finished run

    func testContinueAfterFinishUpgradesOnceToTwoRounds() throws {
        let appModel = makeAppModel()
        let model = RouteSessionModel()
        model.deviceSessionIsActive = { _ in true }
        let route = closedRoute
        try model.prepare(route: route, profile: steadyProfile(), mode: .once, progress: zeroProgress)
        XCTAssertEqual(model.totalLaps, 1)

        model.debugBeginRunning()
        let geometry = try RouteGeometry(points: route.points, isClosed: route.isClosed)
        let finished = try XCTUnwrap(model.debugTick(delta: geometry.totalDistance))
        XCTAssertEqual(finished.phase, .finished)
        model.debugSetPhase(.finished)

        let plan = try XCTUnwrap(model.continuationPlan(additionalLaps: 1))
        XCTAssertEqual(plan.completedLaps, 1)
        XCTAssertEqual(plan.additionalLaps, 1)
        XCTAssertEqual(plan.totalLaps, 2)
        XCTAssertEqual(plan.mode, .laps(2))
        XCTAssertTrue(plan.endsAtStart)

        model.continueAfterFinish(additionalLaps: 1, using: appModel)

        XCTAssertEqual(model.phase, .running)
        XCTAssertEqual(model.totalLaps, 2)
        XCTAssertEqual(model.completedLaps, 1)
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(model.tripCount)

        // The same rule turns a single open traversal into an out-and-back back to the start.
        let openModel = RouteSessionModel()
        openModel.deviceSessionIsActive = { _ in true }
        try openModel.prepare(route: openRoute, profile: steadyProfile(), mode: .once, progress: zeroProgress)
        openModel.debugBeginRunning()
        let openGeometry = try RouteGeometry(points: openRoute.points, isClosed: openRoute.isClosed)
        _ = openModel.debugTick(delta: openGeometry.totalDistance)
        openModel.debugSetPhase(.finished)

        let openPlan = try XCTUnwrap(openModel.continuationPlan(additionalLaps: 1))
        XCTAssertEqual(openPlan.mode, .outAndBack(trips: 2))
        XCTAssertEqual(openPlan.totalLaps, 2)
        XCTAssertTrue(openPlan.endsAtStart)
    }

    func testContinueAfterFinishKeepsDeviceSessionAlive() throws {
        let appModel = makeAppModel()
        let model = RouteSessionModel()
        // A completed lap is enough to park the run in .finished without a live tunnel.
        try model.prepare(
            route: closedRoute,
            profile: steadyProfile(),
            mode: .laps(1),
            progress: RouteRunProgress(distanceInLap: 0, completedLaps: 1, elapsedTime: 60)
        )
        model.debugBeginRunning()
        _ = model.debugTick(delta: 1)
        model.debugSetPhase(.finished)
        XCTAssertEqual(model.phase, .finished)

        model.deviceSessionIsActive = { _ in true }
        model.continueAfterFinish(additionalLaps: 2, using: appModel)

        XCTAssertEqual(model.phase, .running)
        XCTAssertNil(model.errorMessage)
        // No second session: the continuation reused the live one.
        XCTAssertEqual(appModel.debugRouteSessionStartCount, 0)
        XCTAssertEqual(model.completedLaps, 1)
        XCTAssertEqual(model.totalLaps, 3)
        XCTAssertFalse(try XCTUnwrap(appModel.debugActiveSessionRecovery).wasHolding)

        // With the device session gone the run fails loudly and stays finished.
        let droppedModel = RouteSessionModel()
        try droppedModel.prepare(
            route: closedRoute,
            profile: steadyProfile(),
            mode: .laps(1),
            progress: RouteRunProgress(distanceInLap: 0, completedLaps: 1, elapsedTime: 60)
        )
        droppedModel.debugBeginRunning()
        _ = droppedModel.debugTick(delta: 1)
        droppedModel.debugSetPhase(.finished)
        droppedModel.deviceSessionIsActive = { _ in false }

        droppedModel.continueAfterFinish(additionalLaps: 1, using: appModel)

        XCTAssertEqual(droppedModel.phase, .finished)
        XCTAssertNotNil(droppedModel.errorMessage)
        XCTAssertTrue(droppedModel.locksRouteInput)
        XCTAssertEqual(appModel.debugRouteSessionStartCount, 0)
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
