import Foundation

enum RouteRunModeError: Error, Equatable, Sendable {
    /// `.laps` needs a positive lap count.
    case invalidLapCount
    /// `.outAndBack` needs at least one trip.
    case invalidTripCount
    /// `.laps` and `.continuous` only make sense on a closed route.
    case requiresClosedRoute
    /// `.outAndBack` only makes sense on an open route.
    case requiresOpenRoute
}

/// How long a route run lasts: one traversal, a fixed number of laps, forever, or a fixed number
/// of trips along an open route and back again.
enum RouteRunMode: Codable, Equatable, Sendable {
    case once
    case laps(Int)
    case continuous
    /// One trip is a single traversal; the next one runs back. Even trips end where the route
    /// starts, odd trips end at its last point.
    case outAndBack(trips: Int)

    /// Checks the parts of the mode that do not depend on the route geometry. Whether the route is
    /// closed is only known by `RouteRunner`, which enforces `.requiresClosedRoute` and
    /// `.requiresOpenRoute`.
    func validated() throws -> RouteRunMode {
        if case .laps(let count) = self, count < 1 {
            throw RouteRunModeError.invalidLapCount
        }
        if case .outAndBack(let trips) = self, trips < 1 {
            throw RouteRunModeError.invalidTripCount
        }
        return self
    }
}
