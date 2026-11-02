import Foundation
import Observation

/// Where a held run was frozen. A run held mid-route keeps going from the same point; a run held
/// at its finish appends more trips instead.
enum RouteSessionHoldOrigin: Equatable, Sendable {
    case paused
    case finished
}

enum RouteSessionPhase: Equatable {
    case idle
    case preparing
    case running
    case paused
    /// The run stopped advancing but kept its injected coordinate, its device session and its
    /// background keepalive. Nothing is stopped, so continuing is a resume rather than a restart.
    case holding(RouteSessionHoldOrigin)
    case finished
    case stopping
    case failed(String)
}

enum RouteSessionError: Error, Equatable {
    case notPrepared
    case invalidProgress
}

/// How a finished run grows when the user asks for more laps. `.once` is always upgraded, because
/// a single traversal cannot simply repeat: a closed route becomes a lap run, an open one becomes
/// an out-and-back that ends back at the start.
struct RouteContinuationPlan: Equatable, Sendable {
    let completedLaps: Int
    let additionalLaps: Int
    let mode: RouteRunMode
    /// Whether the extended run stops back at the route's first point.
    let endsAtStart: Bool

    var totalLaps: Int { completedLaps + additionalLaps }
}

@MainActor
@Observable
final class RouteSessionModel {
    private(set) var phase: RouteSessionPhase = .idle
    private(set) var route: RouteDefinition?
    private(set) var snapshot: RouteRunSnapshot?
    private(set) var errorMessage: String?

    @ObservationIgnored private var runner: RouteRunner?
    @ObservationIgnored private var geometry: RouteGeometry?
    @ObservationIgnored private var profile: RunProfile?
    @ObservationIgnored private var mode: RouteRunMode?
    @ObservationIgnored private var movementTask: Task<Void, Never>?
    /// Set while a held run reconnects its device session, so the session comes back as `.holding`
    /// rather than pretending the movement was never frozen.
    @ObservationIgnored private var restoredHoldOrigin: RouteSessionHoldOrigin?

    /// Injected so tests can prove a continuation reuses the live device session; production code
    /// never replaces it.
    @ObservationIgnored var deviceSessionIsActive: (AppModel) -> Bool = { appModel in
        if case .active = appModel.deviceSession.phase { return true }
        return false
    }

    var locksRouteInput: Bool {
        switch phase {
        case .preparing, .running, .paused, .stopping, .finished, .holding:
            true
        case .idle, .failed:
            false
        }
    }

    var completedLaps: Int {
        snapshot?.completedLaps ?? 0
    }

    var lapProgress: Double {
        guard let snapshot, let geometry, geometry.totalDistance > 0 else { return 0 }
        return min(max(snapshot.distanceInLap / geometry.totalDistance, 0), 1)
    }

    var totalDistance: Double {
        snapshot?.totalDistance ?? 0
    }

    /// Trips an `.outAndBack` run was set up for, or `nil` for the looping modes.
    var tripCount: Int? {
        guard case .outAndBack(let trips)? = mode else { return nil }
        return trips
    }

    /// The trip in progress, 1-based, held on the last trip once the run finished.
    var tripIndex: Int? {
        guard let tripCount else { return nil }
        return min(completedLaps + 1, tripCount)
    }

    /// Full laps (or trips) the run reaches in total, or `nil` for `.continuous`.
    var totalLaps: Int? {
        guard let mode else { return nil }
        switch mode {
        case .once:
            return 1
        case .laps(let count):
            return count
        case .continuous:
            return nil
        case .outAndBack(let trips):
            return trips
        }
    }

    /// Where a hold would freeze this run, or `nil` when the phase cannot be held.
    var holdOrigin: RouteSessionHoldOrigin? {
        if case .holding(let origin) = phase { return origin }
        return nil
    }

    // MARK: - Preparation

    func prepare(
        route: RouteDefinition,
        profile: RunProfile,
        mode: RouteRunMode,
        progress: RouteRunProgress,
        wasHolding: Bool = false
    ) throws {
        let geometry = try RouteGeometry(points: route.points, isClosed: route.isClosed)
        let mode = try mode.validated()
        try profile.validate()
        guard Self.isValid(progress) else { throw RouteSessionError.invalidProgress }
        let runner = try RouteRunner(geometry: geometry, profile: profile, mode: mode, progress: progress)

        cancelMovement()
        self.route = route
        self.geometry = geometry
        self.profile = profile
        self.mode = mode
        self.runner = runner
        self.snapshot = runner.snapshot
        self.errorMessage = nil
        self.restoredHoldOrigin = nil
        // A recovery record does not store which phase the hold happened in; the progress says it:
        // a run that already reached its lap target was held at the finish.
        self.phase = wasHolding ? .holding(Self.holdOrigin(forProgress: progress, mode: mode)) : .idle
    }

    private static func isValid(_ progress: RouteRunProgress) -> Bool {
        progress.completedLaps >= 0
            && progress.distanceInLap.isFinite
            && progress.distanceInLap >= 0
            && progress.elapsedTime.isFinite
            && progress.elapsedTime >= 0
    }

    private static func holdOrigin(
        forProgress progress: RouteRunProgress,
        mode: RouteRunMode
    ) -> RouteSessionHoldOrigin {
        let targetLaps: Int?
        switch mode {
        case .once: targetLaps = 1
        case .laps(let count): targetLaps = count
        case .outAndBack(let trips): targetLaps = trips
        case .continuous: targetLaps = nil
        }
        guard let targetLaps, progress.completedLaps >= targetLaps else { return .paused }
        return .finished
    }

    // MARK: - Session control

    func start(using appModel: AppModel) async {
        guard let route, let profile, let mode, let runner = runner else {
            fail("Prepare a route before starting it.")
            return
        }
        switch phase {
        case .preparing, .running, .paused, .stopping:
            return
        case .idle, .holding, .finished, .failed:
            break
        }
        guard case .paired = appModel.pairingStatus else {
            fail("Pair this iPhone before starting a route.")
            return
        }

        let heldOrigin = holdOrigin
        restoredHoldOrigin = heldOrigin
        phase = .preparing
        let initialTarget = locationTarget(
            for: runner.snapshot,
            coordinate: runner.snapshot.groundCoordinate,
            route: route
        )
        await appModel.startRouteLocationSession(
            at: initialTarget,
            route: route,
            profile: profile,
            mode: mode
        )
        guard phase == .preparing else { return }

        if appModel.deviceSession.phase == .idle {
            fail("Roam Control could not start the route session.")
            return
        }
        if heldOrigin != nil {
            appModel.armActiveRouteRecovery(
                at: initialTarget,
                route: route,
                progress: progress(of: runner.snapshot),
                profile: profile,
                mode: mode,
                wasHolding: true
            )
        } else {
            appModel.updateActiveRouteRecovery(at: initialTarget, progress: progress(of: runner.snapshot))
        }
        if case .active(let target) = appModel.deviceSession.phase {
            handleDeviceSessionPhase(.active(target), appModel: appModel)
        }
    }

    func togglePause() {
        switch phase {
        case .running:
            runner?.pause()
            snapshot = runner?.snapshot
            phase = .paused
        case .paused:
            runner?.resume()
            snapshot = runner?.snapshot
            phase = .running
        case .idle, .preparing, .holding, .finished, .stopping, .failed:
            break
        }
    }

    /// Freezes the run where it is. The device session is left running, so the injected coordinate
    /// stays in place and continuing does not restart anything.
    func hold(using appModel: AppModel) {
        let origin: RouteSessionHoldOrigin
        switch phase {
        case .running, .paused:
            origin = .paused
        case .finished:
            origin = .finished
        case .idle, .preparing, .holding, .stopping, .failed:
            return
        }
        guard let route, let profile, let mode, var runner = runner else { return }

        cancelMovement()
        if case .running = runner.snapshot.phase {
            runner.pause()
        }
        self.runner = runner
        let frozen = runner.snapshot
        snapshot = frozen
        phase = .holding(origin)
        appModel.armActiveRouteRecovery(
            at: heldTarget(for: frozen, route: route, appModel: appModel),
            route: route,
            progress: progress(of: frozen),
            profile: profile,
            mode: mode,
            wasHolding: true
        )
    }

    /// Continues a held run from the same point: same runner, same distance, same lap.
    func resumeFromHold(using appModel: AppModel) {
        guard case .holding(.paused) = phase else { return }
        guard let route, let profile, let mode, var runner = runner else { return }

        Self.startOrResume(&runner)
        self.runner = runner
        snapshot = runner.snapshot
        errorMessage = nil
        phase = .running
        appModel.armActiveRouteRecovery(
            at: heldTarget(for: runner.snapshot, route: route, appModel: appModel),
            route: route,
            progress: progress(of: runner.snapshot),
            profile: profile,
            mode: mode,
            wasHolding: false
        )
        beginMovement(using: appModel)
    }

    /// Appends more laps to a finished run. The device session is reused as-is: a continuation
    /// never opens a second location session, so no "Starting route session…" and no real-location
    /// flash can appear. A session that already dropped stays `.finished` with an explicit error.
    func continueAfterFinish(additionalLaps: Int = 1, using appModel: AppModel) {
        switch phase {
        case .finished, .holding(.finished):
            break
        case .idle, .preparing, .running, .paused, .holding, .stopping, .failed:
            return
        }
        guard let route, let geometry, let profile, let mode, let runner = runner else { return }
        guard deviceSessionIsActive(appModel) else {
            errorMessage = String(localized: "The location session ended. Restore this iPhone's location and start the route again.")
            phase = .finished
            return
        }

        let extra = max(additionalLaps, 1)
        let nextMode: RouteRunMode
        if let plan = continuationPlan(additionalLaps: extra) {
            nextMode = plan.mode
        } else if case .continuous = mode {
            nextMode = .continuous
        } else {
            return
        }

        let next: RouteRunner
        do {
            next = try RouteRunner(
                geometry: geometry,
                profile: profile,
                mode: nextMode,
                progress: Self.carriedProgress(progress(of: runner.snapshot), from: mode, to: nextMode)
            )
        } catch {
            errorMessage = String(localized: "The run could not continue. Restore this iPhone's location and start the route again.")
            phase = .finished
            return
        }
        guard case .idle = next.snapshot.phase else {
            errorMessage = String(localized: "The run could not continue. Restore this iPhone's location and start the route again.")
            phase = .finished
            return
        }

        self.mode = nextMode
        self.runner = next
        var started = next
        started.start()
        self.runner = started
        snapshot = started.snapshot
        errorMessage = nil
        phase = .running
        appModel.armActiveRouteRecovery(
            at: heldTarget(for: started.snapshot, route: route, appModel: appModel),
            route: route,
            progress: progress(of: started.snapshot),
            profile: profile,
            mode: nextMode,
            wasHolding: false
        )
        beginMovement(using: appModel)
    }

    /// The laps a finished run would reach by adding `additionalLaps`, or `nil` for `.continuous`,
    /// which has no lap target to ask for.
    func continuationPlan(additionalLaps: Int) -> RouteContinuationPlan? {
        guard let snapshot, let geometry, let mode else { return nil }
        let extra = max(additionalLaps, 1)
        let total = snapshot.completedLaps + extra
        switch mode {
        case .continuous:
            return nil
        case .once:
            guard geometry.isClosed else {
                return RouteContinuationPlan(
                    completedLaps: snapshot.completedLaps,
                    additionalLaps: extra,
                    mode: .outAndBack(trips: total),
                    endsAtStart: total % 2 == 0
                )
            }
            return RouteContinuationPlan(
                completedLaps: snapshot.completedLaps,
                additionalLaps: extra,
                mode: .laps(total),
                endsAtStart: true
            )
        case .laps:
            return RouteContinuationPlan(
                completedLaps: snapshot.completedLaps,
                additionalLaps: extra,
                mode: .laps(total),
                endsAtStart: true
            )
        case .outAndBack:
            return RouteContinuationPlan(
                completedLaps: snapshot.completedLaps,
                additionalLaps: extra,
                mode: .outAndBack(trips: total),
                endsAtStart: total % 2 == 0
            )
        }
    }

    /// Re-bases a carried run when the extension changes the measuring convention. A finished
    /// open-route `.once` ends with `distanceInLap == lapLength`, but the follow-up `.outAndBack`
    /// return trip measures backwards from the far end, so carrying that distance would place the
    /// new runner at the start and finish the extra trip on its first tick. Same-convention
    /// upgrades (`.once` → `.laps`, `.laps` → `.laps`, `.outAndBack` → `.outAndBack`) keep it.
    static func carriedProgress(
        _ progress: RouteRunProgress,
        from: RouteRunMode,
        to: RouteRunMode
    ) -> RouteRunProgress {
        guard case .once = from, case .outAndBack = to else { return progress }
        return RouteRunProgress(
            distanceInLap: 0,
            completedLaps: progress.completedLaps,
            elapsedTime: progress.elapsedTime
        )
    }

    func stop(using appModel: AppModel) {
        guard locksRouteInput else { return }
        cancelMovement()
        if appModel.deviceSession.phase == .idle {
            reset()
            return
        }
        phase = .stopping
        appModel.deviceSession.stop()
    }

    func handleDeviceSessionPhase(_ phase: DeviceSessionPhase, appModel: AppModel) {
        switch phase {
        case .active:
            handleActiveDeviceSession(appModel: appModel)
        case .failed(let message):
            guard isActiveRun else { return }
            fail(message)
        case .idle:
            switch self.phase {
            case .stopping:
                cancelMovement()
                reset()
            case .running, .preparing:
                fail("The active location session ended before the route finished.")
            case .idle, .paused, .holding, .finished, .failed:
                break
            }
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            break
        }
    }

    func reset() {
        cancelMovement()
        route = nil
        snapshot = nil
        errorMessage = nil
        runner = nil
        geometry = nil
        profile = nil
        mode = nil
        restoredHoldOrigin = nil
        phase = .idle
    }

    private func handleActiveDeviceSession(appModel: AppModel) {
        guard phase == .preparing, movementTask == nil else { return }
        if let origin = restoredHoldOrigin {
            restoredHoldOrigin = nil
            snapshot = runner?.snapshot
            phase = .holding(origin)
            return
        }
        runner?.start()
        snapshot = runner?.snapshot
        phase = .running
        beginMovement(using: appModel)
    }

    private var isActiveRun: Bool {
        switch phase {
        case .preparing, .running, .paused, .holding, .stopping:
            true
        case .idle, .finished, .failed:
            false
        }
    }

    private func fail(_ message: String) {
        cancelMovement()
        restoredHoldOrigin = nil
        errorMessage = message
        phase = .failed(message)
    }

    // MARK: - Movement

    private func beginMovement(using appModel: AppModel) {
        guard movementTask == nil else { return }
        movementTask = Task { @MainActor [weak self, weak appModel] in
            var lastTick = Date.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, let appModel else { return }
                let now = Date.now
                let delta = now.timeIntervalSince(lastTick)
                lastTick = now
                switch self.phase {
                case .running:
                    self.advance(by: delta, using: appModel)
                case .paused, .holding:
                    continue
                case .idle, .preparing, .finished, .stopping, .failed:
                    return
                }
            }
        }
    }

    private func advance(by delta: TimeInterval, using appModel: AppModel) {
        guard let route, let next = applyTick(delta: delta) else { return }

        let target = locationTarget(for: next, coordinate: next.reportedCoordinate, route: route)
        guard appModel.deviceSession.updateLocation(target) == .updated else {
            fail("The active location session ended before the route finished.")
            return
        }
        if next.phase == .finished {
            finish(at: target, using: appModel)
        } else {
            appModel.updateActiveRouteRecovery(at: target, progress: progress(of: next))
        }
    }

    /// One movement tick against the runner, without touching the device session.
    @discardableResult
    private func applyTick(delta: TimeInterval) -> RouteRunSnapshot? {
        guard var runner, phase == .running else { return nil }
        let next = runner.advance(by: delta)
        self.runner = runner
        snapshot = next
        return next
    }

    private static func startOrResume(_ runner: inout RouteRunner) {
        switch runner.snapshot.phase {
        case .idle:
            runner.start()
        case .paused:
            runner.resume()
        case .running, .finished:
            break
        }
    }

    /// Ends the run: movement stops and the recovery record turns back into a fixed location.
    private func finish(at target: LocationTarget, using appModel: AppModel) {
        cancelMovement()
        phase = .finished
        appModel.finishActiveRouteRecovery(at: target)
    }

    private func cancelMovement() {
        movementTask?.cancel()
        movementTask = nil
    }

    /// The injected coordinate the session is already holding, so a hold or a continuation keeps
    /// the recovery record pointing at the point the iPhone is really reporting.
    private func heldTarget(
        for snapshot: RouteRunSnapshot,
        route: RouteDefinition,
        appModel: AppModel
    ) -> LocationTarget {
        if case .active(let target) = appModel.deviceSession.phase {
            return target
        }
        return locationTarget(for: snapshot, coordinate: snapshot.reportedCoordinate, route: route)
    }

    // MARK: - Targets

    private func locationTarget(
        for snapshot: RouteRunSnapshot,
        coordinate: GeoCoordinate,
        route: RouteDefinition
    ) -> LocationTarget {
        LocationTarget(
            name: String(format: String(localized: "Running %@"), route.name),
            subtitle: String(
                format: String(localized: "%lld laps · %@ m/s · %lld spm"),
                snapshot.completedLaps,
                String(format: "%.1f", snapshot.speedMetersPerSecond),
                Int(snapshot.cadenceStepsPerMinute.rounded())
            ),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private func progress(of snapshot: RouteRunSnapshot) -> RouteRunProgress {
        RouteRunProgress(
            distanceInLap: snapshot.distanceInLap,
            completedLaps: snapshot.completedLaps,
            elapsedTime: snapshot.elapsedTime
        )
    }
}

#if DEBUG
extension RouteSessionModel {
    /// Test seam: starts the prepared runner where an active device session would have left it,
    /// so phase transitions can be exercised without the tunnel.
    func debugBeginRunning() {
        guard var runner else { return }
        Self.startOrResume(&runner)
        self.runner = runner
        snapshot = runner.snapshot
        phase = .running
    }

    /// Test seam: parks the prepared run in `phase`, the way the finish path would leave it.
    func debugSetPhase(_ phase: RouteSessionPhase) {
        self.phase = phase
        snapshot = runner?.snapshot
    }

    /// Test seam: one movement tick, exactly as the live loop applies it, without pushing to the
    /// device session.
    @discardableResult
    func debugTick(delta: TimeInterval) -> RouteRunSnapshot? {
        applyTick(delta: delta)
    }
}
#endif
