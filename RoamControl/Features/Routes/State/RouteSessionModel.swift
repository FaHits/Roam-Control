import Foundation
import Observation

enum RouteSessionPhase: Equatable {
    case idle
    case preparing
    case running
    case paused
    case finished
    case stopping
    case failed(String)
}

enum RouteSessionError: Error, Equatable {
    case notPrepared
    case invalidProgress
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

    var locksRouteInput: Bool {
        switch phase {
        case .preparing, .running, .paused, .stopping, .finished:
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

    // MARK: - Preparation

    func prepare(
        route: RouteDefinition,
        profile: RunProfile,
        mode: RouteRunMode,
        progress: RouteRunProgress
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
        self.phase = .idle
    }

    private static func isValid(_ progress: RouteRunProgress) -> Bool {
        progress.completedLaps >= 0
            && progress.distanceInLap.isFinite
            && progress.distanceInLap >= 0
            && progress.elapsedTime.isFinite
            && progress.elapsedTime >= 0
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
        case .idle, .finished, .failed:
            break
        }
        guard case .paired = appModel.pairingStatus else {
            fail("Pair this iPhone before starting a route.")
            return
        }

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
        appModel.updateActiveRouteRecovery(at: initialTarget, progress: progress(of: runner.snapshot))
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
        case .idle, .preparing, .finished, .stopping, .failed:
            break
        }
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
            guard self.phase == .preparing, movementTask == nil else { return }
            runner?.start()
            snapshot = runner?.snapshot
            self.phase = .running
            beginMovement(using: appModel)
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
            case .idle, .paused, .finished, .failed:
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
        phase = .idle
    }

    private var isActiveRun: Bool {
        switch phase {
        case .preparing, .running, .paused, .stopping:
            true
        case .idle, .finished, .failed:
            false
        }
    }

    private func fail(_ message: String) {
        cancelMovement()
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
                case .paused:
                    continue
                case .idle, .preparing, .finished, .stopping, .failed:
                    return
                }
            }
        }
    }

    private func advance(by delta: TimeInterval, using appModel: AppModel) {
        guard var runner = runner, let route, phase == .running else { return }
        let next = runner.advance(by: delta)
        self.runner = runner
        snapshot = next
        guard phase == .running else { return }

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

    private func finish(at target: LocationTarget, using appModel: AppModel) {
        cancelMovement()
        phase = .finished
        appModel.finishActiveRouteRecovery(at: target)
    }

    private func cancelMovement() {
        movementTask?.cancel()
        movementTask = nil
    }

    // MARK: - Targets

    private func locationTarget(
        for snapshot: RouteRunSnapshot,
        coordinate: GeoCoordinate,
        route: RouteDefinition
    ) -> LocationTarget {
        LocationTarget(
            name: "Running \(route.name)",
            subtitle: "\(snapshot.completedLaps) laps · \(String(format: "%.1f", snapshot.speedMetersPerSecond)) m/s · \(Int(snapshot.cadenceStepsPerMinute.rounded())) spm",
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
