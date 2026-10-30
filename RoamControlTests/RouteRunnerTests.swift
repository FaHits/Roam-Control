import XCTest
@testable import RoamControl

final class RouteRunnerTests: XCTestCase {
    private let start = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)

    /// Roughly 414 m square loop; the closing segment runs from the last point back to `start`.
    private var square: [GeoCoordinate] {
        [
            start,
            GeoCoordinate(latitude: 31.2304, longitude: 121.4747),
            GeoCoordinate(latitude: 31.2314, longitude: 121.4747),
            GeoCoordinate(latitude: 31.2314, longitude: 121.4737)
        ]
    }

    private var openPoints: [GeoCoordinate] {
        Array(square.prefix(3))
    }

    /// Zero variation and zero jitter make speed, cadence and the ground coordinate exact, so the
    /// distance assertions below do not have to absorb motion-model noise.
    private func steadyProfile(speed: Double = 2.0) -> RunProfile {
        RunProfile(
            targetSpeedMetersPerSecond: speed,
            targetCadenceStepsPerMinute: 170,
            speedVariationFraction: 0,
            cadenceVariationFraction: 0,
            gpsJitterRadiusMeters: 0,
            noiseSeed: 0x5255_4E31
        )
    }

    private func closedGeometry() throws -> RouteGeometry {
        try RouteGeometry(points: square, isClosed: true)
    }

    private func openGeometry() throws -> RouteGeometry {
        try RouteGeometry(points: openPoints, isClosed: false)
    }

    // MARK: - Initial state

    func testStartsAtFirstRouteCoordinate() throws {
        let geometry = try closedGeometry()
        let runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .continuous
        )

        XCTAssertEqual(runner.phase, .idle)
        XCTAssertEqual(runner.snapshot.phase, .idle)
        XCTAssertEqual(geometry.points.first, start)
        XCTAssertEqual(runner.snapshot.groundCoordinate, start)
        // A zero jitter radius reports the ground coordinate verbatim.
        XCTAssertEqual(runner.snapshot.reportedCoordinate, start)
        XCTAssertEqual(runner.snapshot.distanceInLap, 0)
        XCTAssertEqual(runner.snapshot.completedLaps, 0)
        XCTAssertEqual(runner.snapshot.totalDistance, 0)
        XCTAssertEqual(runner.snapshot.elapsedTime, 0)
        XCTAssertEqual(runner.snapshot.speedMetersPerSecond, 2.0)
        XCTAssertEqual(runner.snapshot.cadenceStepsPerMinute, 170)
    }

    func testProgressInitializerRestoresMidLapPosition() throws {
        let geometry = try closedGeometry()
        let lapLength = geometry.totalDistance
        let progress = RouteRunProgress(distanceInLap: 100, completedLaps: 3, elapsedTime: 250)
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .continuous,
            progress: progress
        )

        XCTAssertEqual(runner.phase, .idle)
        XCTAssertEqual(runner.snapshot.completedLaps, 3)
        XCTAssertEqual(runner.snapshot.distanceInLap, 100)
        XCTAssertEqual(runner.snapshot.elapsedTime, 250)
        XCTAssertEqual(runner.snapshot.totalDistance, 3 * lapLength + 100, accuracy: 1e-6)
        XCTAssertEqual(runner.snapshot.groundCoordinate, geometry.coordinate(atDistance: 100))
        XCTAssertEqual(runner.snapshot.reportedCoordinate, geometry.coordinate(atDistance: 100))
        XCTAssertNotEqual(runner.snapshot.groundCoordinate, start)

        runner.start()
        let snapshot = runner.advance(by: 5)

        // Five seconds at 2 m/s must continue from 100 m, not restart from the first point.
        XCTAssertEqual(snapshot.completedLaps, 3)
        XCTAssertEqual(snapshot.distanceInLap, 110, accuracy: 1e-9)
        XCTAssertEqual(snapshot.elapsedTime, 255)
        XCTAssertEqual(snapshot.groundCoordinate, geometry.coordinate(atDistance: 110))
        XCTAssertNotEqual(snapshot.groundCoordinate, start)
    }

    // MARK: - Pause and resume

    func testPauseDoesNotAdvanceProgress() throws {
        let geometry = try closedGeometry()
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .continuous
        )
        runner.start()
        let afterTenSeconds = runner.advance(by: 10)

        runner.pause()
        let pausedSnapshot = runner.snapshot
        XCTAssertEqual(runner.phase, .paused)
        XCTAssertEqual(pausedSnapshot.phase, .paused)

        let whilePaused = runner.advance(by: 60)

        XCTAssertEqual(whilePaused, pausedSnapshot)
        XCTAssertEqual(runner.snapshot, pausedSnapshot)
        XCTAssertEqual(runner.snapshot.distanceInLap, 20, accuracy: 1e-9)
        XCTAssertEqual(runner.snapshot.elapsedTime, 10)
        XCTAssertEqual(runner.snapshot.groundCoordinate, afterTenSeconds.groundCoordinate)
    }

    func testResumeContinuesFromPausedCoordinate() throws {
        let geometry = try closedGeometry()
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .continuous
        )
        runner.start()
        let pausedAt = runner.advance(by: 10)
        runner.pause()
        _ = runner.advance(by: 30)

        runner.resume()
        XCTAssertEqual(runner.phase, .running)

        let snapshot = runner.advance(by: 5)

        XCTAssertEqual(snapshot.elapsedTime, 15)
        XCTAssertEqual(snapshot.completedLaps, 0)
        XCTAssertEqual(snapshot.distanceInLap, 30, accuracy: 1e-9)
        XCTAssertEqual(snapshot.groundCoordinate, geometry.coordinate(atDistance: 30))
        XCTAssertGreaterThan(
            snapshot.groundCoordinate.distance(to: pausedAt.groundCoordinate),
            9
        )
    }

    func testInvalidDeltasAreIgnoredWhileRunning() throws {
        let geometry = try closedGeometry()
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .continuous
        )
        runner.start()
        let reference = runner.advance(by: 10)

        for delta in [0.0, -5.0, Double.nan, .infinity, -.infinity] {
            let snapshot = runner.advance(by: delta)
            XCTAssertEqual(snapshot, reference, "delta \(delta) must not move the run")
            XCTAssertEqual(runner.phase, .running, "delta \(delta) must not change the phase")
        }
    }

    // MARK: - Finite and open runs

    func testFiniteLapRunFinishesAfterRequestedLapCount() throws {
        let geometry = try closedGeometry()
        let lapLength = geometry.totalDistance
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .laps(2)
        )
        runner.start()

        let secondsPerLap = lapLength / 2.0
        var ticks = 0
        while runner.phase != .finished && ticks < 10 {
            runner.advance(by: secondsPerLap)
            ticks += 1
        }

        XCTAssertEqual(ticks, 2)
        XCTAssertEqual(runner.phase, .finished)
        XCTAssertEqual(runner.snapshot.phase, .finished)
        XCTAssertEqual(runner.snapshot.completedLaps, 2)
        XCTAssertEqual(runner.snapshot.distanceInLap, 0)
        XCTAssertEqual(runner.snapshot.groundCoordinate, start)
        XCTAssertEqual(runner.snapshot.elapsedTime, 2 * secondsPerLap, accuracy: 1e-9)
        XCTAssertEqual(runner.snapshot.totalDistance, 2 * lapLength, accuracy: 1e-6)
    }

    func testOpenRouteFinishesAtFinalCoordinate() throws {
        let geometry = try openGeometry()
        let totalDistance = geometry.totalDistance
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .once
        )
        runner.start()

        let delta = totalDistance / 2 + 100
        let snapshot = runner.advance(by: delta)

        XCTAssertEqual(runner.phase, .finished)
        XCTAssertEqual(snapshot.phase, .finished)
        XCTAssertEqual(snapshot.groundCoordinate, openPoints.last)
        XCTAssertEqual(snapshot.groundCoordinate, geometry.points.last)
        XCTAssertEqual(snapshot.distanceInLap, totalDistance)
        XCTAssertEqual(snapshot.completedLaps, 1)
        XCTAssertEqual(snapshot.totalDistance, totalDistance)
        // The runner stops at the end of the route but still records the wall-clock delta.
        XCTAssertEqual(snapshot.elapsedTime, delta, accuracy: 1e-9)
    }

    func testClosedOnceRunFinishesWithOneCompletedLap() throws {
        let geometry = try closedGeometry()
        let lapLength = geometry.totalDistance
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .once
        )
        runner.start()

        let delta = lapLength * 3
        let snapshot = runner.advance(by: delta)

        XCTAssertEqual(runner.phase, .finished)
        XCTAssertEqual(snapshot.completedLaps, 1)
        XCTAssertEqual(snapshot.distanceInLap, 0)
        XCTAssertEqual(snapshot.groundCoordinate, start)
        XCTAssertEqual(snapshot.totalDistance, lapLength, accuracy: 1e-6)
        XCTAssertEqual(snapshot.elapsedTime, delta, accuracy: 1e-9)
    }

    func testFinishedRunnerIsTerminal() throws {
        let geometry = try closedGeometry()
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .laps(1)
        )
        runner.start()
        let finished = runner.advance(by: geometry.totalDistance / 2 + 30)

        let afterFinish = runner.advance(by: 600)

        XCTAssertEqual(afterFinish, finished)
        XCTAssertEqual(runner.phase, .finished)
        XCTAssertEqual(runner.snapshot.completedLaps, 1)
        XCTAssertEqual(runner.snapshot.distanceInLap, 0)
        XCTAssertEqual(runner.snapshot.elapsedTime, finished.elapsedTime)
    }

    // MARK: - Looping

    func testContinuousRouteWrapsWithoutASeamJump() throws {
        let geometry = try closedGeometry()
        let lapLength = geometry.totalDistance
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .continuous
        )
        runner.start()

        // Stop one metre before the seam, then run one more second (2 m at 2 m/s).
        let beforeSeam = runner.advance(by: (lapLength - 1) / 2)
        XCTAssertEqual(beforeSeam.completedLaps, 0)
        XCTAssertEqual(beforeSeam.distanceInLap, lapLength - 1, accuracy: 1e-9)

        let afterSeam = runner.advance(by: 1)

        XCTAssertEqual(afterSeam.completedLaps, 1)
        XCTAssertEqual(afterSeam.distanceInLap, 1, accuracy: 1e-9)
        XCTAssertEqual(runner.phase, .running)

        let gap = beforeSeam.groundCoordinate.distance(to: afterSeam.groundCoordinate)
        XCTAssertLessThan(gap, 2.5, "crossing the seam must not jump back across the loop")
        XCTAssertGreaterThan(gap, 0.5, "the runner must still move forward")

        XCTAssertTrue(beforeSeam.speedMetersPerSecond.isFinite)
        XCTAssertTrue(afterSeam.speedMetersPerSecond.isFinite)
        XCTAssertTrue(beforeSeam.cadenceStepsPerMinute.isFinite)
        XCTAssertTrue(afterSeam.cadenceStepsPerMinute.isFinite)
        XCTAssertGreaterThan(afterSeam.speedMetersPerSecond, 0)
    }

    func testCompletedLapIncrementsExactlyOnceAtSeam() throws {
        let geometry = try closedGeometry()
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(speed: 1.0),
            mode: .continuous
        )
        runner.start()

        var previousLaps = 0
        var seamCrossedAt = -1
        for tick in 0..<2000 {
            // Half a second at 1 m/s is exactly 0.5 m, so the seam falls mid-tick.
            let snapshot = runner.advance(by: 0.5)
            let increase = snapshot.completedLaps - previousLaps
            XCTAssertTrue(increase == 0 || increase == 1, "lap count jumped by \(increase)")
            previousLaps = snapshot.completedLaps
            if snapshot.completedLaps == 1 && seamCrossedAt < 0 {
                seamCrossedAt = tick
                XCTAssertLessThan(snapshot.distanceInLap, 0.5)
            }
            if seamCrossedAt >= 0 && snapshot.distanceInLap >= 3 {
                break
            }
        }

        XCTAssertGreaterThanOrEqual(seamCrossedAt, 0, "the loop never crossed its seam")
        XCTAssertEqual(runner.snapshot.completedLaps, 1)
        XCTAssertGreaterThanOrEqual(runner.snapshot.distanceInLap, 3)
        XCTAssertLessThan(runner.snapshot.distanceInLap, 3.5)
        XCTAssertEqual(runner.phase, .running)
    }

    func testLargeAdvanceCanCrossMultipleLaps() throws {
        let geometry = try closedGeometry()
        let lapLength = geometry.totalDistance
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(),
            mode: .continuous
        )
        runner.start()

        // 4.5 laps in a single tick, then another three laps on top of the half lap left over.
        let first = runner.advance(by: 4.5 * lapLength / 2)
        XCTAssertEqual(first.completedLaps, 4)
        XCTAssertEqual(first.distanceInLap, lapLength * 0.5, accuracy: 1e-6)
        XCTAssertEqual(first.groundCoordinate, geometry.coordinate(atDistance: first.distanceInLap))
        XCTAssertEqual(first.totalDistance, 4 * lapLength + first.distanceInLap, accuracy: 1e-6)

        let second = runner.advance(by: 3 * lapLength / 2)
        XCTAssertEqual(second.completedLaps, 7)
        XCTAssertEqual(second.distanceInLap, lapLength * 0.5, accuracy: 1e-6)
        XCTAssertEqual(second.groundCoordinate, geometry.coordinate(atDistance: second.distanceInLap))
        XCTAssertEqual(second.totalDistance, 7 * lapLength + second.distanceInLap, accuracy: 1e-6)
        XCTAssertEqual(runner.phase, .running)
    }

    func testThousandLapsDoNotAccumulateLapError() throws {
        let geometry = try closedGeometry()
        let lapLength = geometry.totalDistance
        let speed = 4.0
        var runner = try RouteRunner(
            geometry: geometry,
            profile: steadyProfile(speed: speed),
            mode: .laps(1000)
        )
        runner.start()

        var ticks = 0
        while runner.phase != .finished && ticks < 400_000 {
            runner.advance(by: 1)
            ticks += 1
        }

        XCTAssertEqual(runner.phase, .finished)
        XCTAssertEqual(runner.snapshot.completedLaps, 1000)
        XCTAssertEqual(runner.snapshot.distanceInLap, 0)
        XCTAssertEqual(runner.snapshot.groundCoordinate, start)
        XCTAssertEqual(runner.snapshot.totalDistance, 1000 * lapLength, accuracy: 1e-6)

        // Finishing a tick early or late would be the visible symptom of lap drift.
        let expectedTicks = Int((1000 * lapLength / speed).rounded(.up))
        XCTAssertLessThanOrEqual(abs(ticks - expectedTicks), 1, "finished after \(ticks) ticks")
        XCTAssertEqual(runner.snapshot.elapsedTime, Double(ticks), accuracy: 1e-9)
    }

    // MARK: - Mode validation

    func testLapsZeroIsRejected() throws {
        XCTAssertThrowsError(try RouteRunMode.laps(0).validated()) { error in
            XCTAssertEqual(error as? RouteRunModeError, .invalidLapCount)
        }

        let geometry = try closedGeometry()
        XCTAssertThrowsError(
            try RouteRunner(geometry: geometry, profile: steadyProfile(), mode: .laps(0))
        ) { error in
            XCTAssertEqual(error as? RouteRunModeError, .invalidLapCount)
        }
    }

    func testNegativeLapCountIsRejected() throws {
        XCTAssertThrowsError(try RouteRunMode.laps(-1).validated()) { error in
            XCTAssertEqual(error as? RouteRunModeError, .invalidLapCount)
        }

        let geometry = try closedGeometry()
        XCTAssertThrowsError(
            try RouteRunner(geometry: geometry, profile: steadyProfile(), mode: .laps(-1))
        ) { error in
            XCTAssertEqual(error as? RouteRunModeError, .invalidLapCount)
        }
    }

    func testValidModesPassValidation() throws {
        XCTAssertEqual(try RouteRunMode.once.validated(), .once)
        XCTAssertEqual(try RouteRunMode.laps(1).validated(), .laps(1))
        XCTAssertEqual(try RouteRunMode.continuous.validated(), .continuous)
    }

    func testOpenRouteRejectsContinuousMode() throws {
        let geometry = try openGeometry()
        XCTAssertThrowsError(
            try RouteRunner(geometry: geometry, profile: steadyProfile(), mode: .continuous)
        ) { error in
            XCTAssertEqual(error as? RouteRunModeError, .requiresClosedRoute)
        }
    }

    func testOpenRouteRejectsLapsMode() throws {
        let geometry = try openGeometry()
        XCTAssertThrowsError(
            try RouteRunner(geometry: geometry, profile: steadyProfile(), mode: .laps(2))
        ) { error in
            XCTAssertEqual(error as? RouteRunModeError, .requiresClosedRoute)
        }
    }
}
