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
    /// Set when the run was frozen at its current point. Records written before the hold phase
    /// existed have no such key and decode as `false`.
    var wasHolding: Bool = false

    enum CodingKeys: String, CodingKey {
        case kind
        case lastReportedLocation
        case destination
        case walkingPaceMetresPerSecond
        case startedAt
        case updatedAt
        case savedRoute
        case routeProgress
        case runProfile
        case runMode
        case wasHolding
    }

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

extension SessionRecoveryRecord {
    /// Hand-written so the memberwise initialiser and the factories above keep working, and so a
    /// record written before the hold phase existed still decodes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        lastReportedLocation = try container.decode(LocationTarget.self, forKey: .lastReportedLocation)
        destination = try container.decodeIfPresent(LocationTarget.self, forKey: .destination)
        walkingPaceMetresPerSecond = try container.decodeIfPresent(
            Double.self,
            forKey: .walkingPaceMetresPerSecond
        )
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        savedRoute = try container.decodeIfPresent(RouteDefinition.self, forKey: .savedRoute)
        routeProgress = try container.decodeIfPresent(RouteRunProgress.self, forKey: .routeProgress)
        runProfile = try container.decodeIfPresent(RunProfile.self, forKey: .runProfile)
        runMode = try container.decodeIfPresent(RouteRunMode.self, forKey: .runMode)
        wasHolding = try container.decodeIfPresent(Bool.self, forKey: .wasHolding) ?? false
    }
}
