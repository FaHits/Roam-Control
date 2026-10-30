import Foundation

enum RouteRunnerPhase: Equatable, Sendable {
    case idle
    case running
    case paused
    case finished
}

/// Everything needed to resume a run without the route library.
struct RouteRunProgress: Codable, Equatable, Sendable {
    var distanceInLap: Double
    var completedLaps: Int
    var elapsedTime: TimeInterval
}

/// One frame of a run: where the runner is, what it reports, and how far it has gone.
struct RouteRunSnapshot: Equatable, Sendable {
    var groundCoordinate: GeoCoordinate
    var reportedCoordinate: GeoCoordinate
    var speedMetersPerSecond: Double
    var cadenceStepsPerMinute: Double
    var distanceInLap: Double
    /// Ground distance covered so far: completed laps plus the current lap.
    var totalDistance: Double
    var completedLaps: Int
    var elapsedTime: TimeInterval
    var phase: RouteRunnerPhase
}

/// Pure route runner: it owns no clock, no device session and no UI. Callers pass the elapsed
/// delta, so tests and the session model drive it the same way.
///
/// The ground coordinate advances at the humanized speed; GPS jitter only moves the reported
/// coordinate. Lap counting uses one division per tick, so a single large delta can cross several
/// seams without double counting them.
struct RouteRunner: Sendable {
    /// Seam tolerance, scaled to the lap length: one micrometre on a one kilometre loop. It keeps
    /// 0.999999 laps from being lost and 1.000001 laps from being counted twice.
    private static let relativeLapTolerance = 1e-9

    let geometry: RouteGeometry
    let profile: RunProfile
    let mode: RouteRunMode

    private let motion: HumanizedMotionModel
    private(set) var snapshot: RouteRunSnapshot

    var phase: RouteRunnerPhase { snapshot.phase }

    private var lapLength: Double { geometry.totalDistance }

    private var lapTolerance: Double {
        max(Self.relativeLapTolerance, lapLength * Self.relativeLapTolerance)
    }

    /// Full laps the run ends after, or `nil` when it loops forever.
    private var targetLaps: Int? {
        switch mode {
        case .once:
            return 1
        case .laps(let count):
            return count
        case .continuous:
            return nil
        }
    }

    init(
        geometry: RouteGeometry,
        profile: RunProfile,
        mode: RouteRunMode,
        progress: RouteRunProgress = .init(distanceInLap: 0, completedLaps: 0, elapsedTime: 0)
    ) throws {
        _ = try mode.validated()
        guard geometry.isClosed || mode == .once else {
            throw RouteRunModeError.requiresClosedRoute
        }

        self.geometry = geometry
        self.profile = profile
        self.mode = mode

        let motion = HumanizedMotionModel(seed: profile.noiseSeed)
        self.motion = motion

        let distanceInLap = min(max(progress.distanceInLap, 0), geometry.totalDistance)
        let ground = geometry.coordinate(atDistance: distanceInLap)
        let coveredDistance = geometry.isClosed
            ? Double(progress.completedLaps) * geometry.totalDistance + distanceInLap
            : distanceInLap

        self.snapshot = RouteRunSnapshot(
            groundCoordinate: ground,
            reportedCoordinate: motion.reportedCoordinate(
                for: ground,
                at: progress.elapsedTime,
                profile: profile
            ),
            speedMetersPerSecond: motion.speedMetersPerSecond(
                at: progress.elapsedTime,
                profile: profile
            ),
            cadenceStepsPerMinute: motion.cadenceStepsPerMinute(
                at: progress.elapsedTime,
                profile: profile
            ),
            distanceInLap: distanceInLap,
            totalDistance: coveredDistance,
            completedLaps: progress.completedLaps,
            elapsedTime: progress.elapsedTime,
            phase: .idle
        )
    }

    // MARK: - Commands

    /// Only `idle -> running`; any other phase keeps the current state.
    mutating func start() {
        guard snapshot.phase == .idle else { return }
        snapshot.phase = .running
    }

    /// Only `running -> paused`; any other phase keeps the current state.
    mutating func pause() {
        guard snapshot.phase == .running else { return }
        snapshot.phase = .paused
    }

    /// Only `paused -> running`; any other phase keeps the current state.
    mutating func resume() {
        guard snapshot.phase == .paused else { return }
        snapshot.phase = .running
    }

    // MARK: - Ticking

    /// Advances the run by `delta` seconds of wall-clock time and returns the new snapshot.
    ///
    /// Non-positive or non-finite deltas and any phase other than `.running` leave the state
    /// untouched. The tick is never capped: a delayed callback still moves the runner the full
    /// distance it owes.
    mutating func advance(by delta: TimeInterval) -> RouteRunSnapshot {
        guard snapshot.phase == .running, delta.isFinite, delta > 0 else { return snapshot }

        // The tick is driven by the speed at the new elapsed time, but the jitter stays out of the
        // distance bookkeeping.
        let elapsed = snapshot.elapsedTime + delta
        let speed = motion.speedMetersPerSecond(at: elapsed, profile: profile)
        let step = speed * delta

        if geometry.isClosed {
            advanceLoop(by: step)
        } else {
            advanceOpenRoute(by: step)
        }

        snapshot.elapsedTime = elapsed
        snapshot.speedMetersPerSecond = speed
        snapshot.cadenceStepsPerMinute = motion.cadenceStepsPerMinute(
            at: elapsed,
            profile: profile
        )
        snapshot.reportedCoordinate = motion.reportedCoordinate(
            for: snapshot.groundCoordinate,
            at: elapsed,
            profile: profile
        )
        if let targetLaps, snapshot.completedLaps >= targetLaps {
            snapshot.phase = .finished
        }
        return snapshot
    }

    /// Open routes always run once, from the first point to the last one.
    private mutating func advanceOpenRoute(by step: Double) {
        let travelled = min(snapshot.distanceInLap + step, lapLength)
        let finished = travelled >= lapLength - lapTolerance
        let distanceInLap = finished ? lapLength : travelled

        snapshot.distanceInLap = distanceInLap
        snapshot.completedLaps = finished ? 1 : 0
        snapshot.totalDistance = distanceInLap
        // `coordinate(atDistance: totalDistance)` is the final point, so the last frame lands on it
        // exactly instead of on an interpolation.
        snapshot.groundCoordinate = geometry.coordinate(atDistance: distanceInLap)
    }

    /// Closed routes: the whole travelled distance is split into laps and a remainder in one step.
    private mutating func advanceLoop(by step: Double) {
        var covered = Double(snapshot.completedLaps) * lapLength + snapshot.distanceInLap + step
        if let targetLaps {
            // Do not run past the last requested lap; the elapsed time still grows by the full
            // delta in the caller.
            covered = min(covered, Double(targetLaps) * lapLength)
        }

        var completedLaps = Int((covered / lapLength).rounded(.down))
        var distanceInLap = covered - Double(completedLaps) * lapLength
        if lapLength - distanceInLap <= lapTolerance {
            completedLaps += 1
            distanceInLap = 0
        } else if distanceInLap <= lapTolerance {
            distanceInLap = 0
        }

        snapshot.completedLaps = completedLaps
        snapshot.distanceInLap = distanceInLap
        snapshot.totalDistance = Double(completedLaps) * lapLength + distanceInLap
        // The seam lives in `RouteGeometry`: a zero remainder is the first point, never a jump.
        snapshot.groundCoordinate = geometry.coordinate(atDistance: distanceInLap)
    }
}
