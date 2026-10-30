import Foundation

enum RouteRunModeError: Error, Equatable, Sendable {
    /// `.laps` needs a positive lap count.
    case invalidLapCount
    /// `.laps` and `.continuous` only make sense on a closed route.
    case requiresClosedRoute
}

/// How long a route run lasts: one traversal, a fixed number of laps, or forever.
enum RouteRunMode: Codable, Equatable, Sendable {
    case once
    case laps(Int)
    case continuous

    /// Checks the parts of the mode that do not depend on the route geometry. Whether the route is
    /// closed is only known by `RouteRunner`, which enforces `.requiresClosedRoute`.
    func validated() throws -> RouteRunMode {
        if case .laps(let count) = self, count < 1 {
            throw RouteRunModeError.invalidLapCount
        }
        return self
    }
}
