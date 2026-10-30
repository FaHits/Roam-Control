import Foundation

struct SessionRecoveryRecord: Codable, Equatable {
    enum Kind: String, Codable {
        case fixedLocation
        case walkingRoute
        case savedRoute
    }

    var kind: Kind
    var lastReportedLocation: LocationTarget
    var destination: LocationTarget?
    var walkingPaceMetresPerSecond: Double?
    let startedAt: Date
    var updatedAt: Date
    var savedRoute: RouteDefinition? = nil
    var routeProgress: RouteRunProgress? = nil
    var runProfile: RunProfile? = nil
    var runMode: RouteRunMode? = nil

    var isWalkingRoute: Bool {
        kind == .walkingRoute && destination != nil
    }

    var isSavedRoute: Bool {
        kind == .savedRoute
    }

    var isRouteSession: Bool {
        kind == .walkingRoute || kind == .savedRoute
    }

    static func fixed(at target: LocationTarget) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: .fixedLocation,
            lastReportedLocation: target,
            destination: nil,
            walkingPaceMetresPerSecond: nil,
            startedAt: .now,
            updatedAt: .now
        )
    }

    static func walking(
        from start: LocationTarget,
        to destination: LocationTarget,
        paceMetresPerSecond: Double
    ) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: .walkingRoute,
            lastReportedLocation: start,
            destination: destination,
            walkingPaceMetresPerSecond: paceMetresPerSecond,
            startedAt: .now,
            updatedAt: .now
        )
    }

    static func savedRoute(
        route: RouteDefinition,
        at initialTarget: LocationTarget,
        progress: RouteRunProgress,
        profile: RunProfile,
        mode: RouteRunMode
    ) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: .savedRoute,
            lastReportedLocation: initialTarget,
            destination: nil,
            walkingPaceMetresPerSecond: nil,
            startedAt: .now,
            updatedAt: .now,
            savedRoute: route,
            routeProgress: progress,
            runProfile: profile,
            runMode: mode
        )
    }
}
