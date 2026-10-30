import Foundation
import Observation

enum RouteEditorError: Error, Equatable, Sendable {
    case emptyName
}

/// Editable draft of a route: the point list plus the closed-loop switch the editor screen binds to.
///
/// `points` holds the raw taps, including the near-duplicate taps `appendPoint` drops, so undo and
/// clear behave exactly as the user drew. Everything that has to agree with the saved route — the
/// effective point count, the total distance and whether saving is allowed — is derived from
/// `RouteGeometry` or from the same duplicate rule, never recomputed with a second threshold.
@MainActor
@Observable
final class RouteEditorModel {
    var name: String
    private(set) var points: [GeoCoordinate]
    var isClosed: Bool
    private(set) var errorMessage: String?

    init(route: RouteDefinition? = nil) {
        self.name = route?.name ?? Self.defaultName
        self.points = route?.points ?? []
        self.isClosed = route?.isClosed ?? true
        self.errorMessage = nil
    }

    // MARK: - Derived state

    /// Saving needs a route geometry that fits the current points and mode, plus a name that survives
    /// trimming. The name check trims exactly like `makeRoute`, so the button can never be enabled for
    /// a draft that saving would reject.
    var canSave: Bool {
        temporaryGeometry != nil && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Same collapse rule as `RouteGeometry`, computed without constructing one: the editor still
    /// has to show a count for drafts that are too short to form a geometry.
    var effectivePointCount: Int {
        Self.effectivePoints(in: points, isClosed: isClosed).count
    }

    /// Zero while the geometry is invalid; a closed route's total includes the closing segment.
    var totalDistance: Double { temporaryGeometry?.totalDistance ?? 0 }

    var canUndo: Bool { !points.isEmpty }

    // MARK: - Editing

    func appendPoint(_ coordinate: GeoCoordinate) {
        guard coordinate.isValid else {
            errorMessage = Self.invalidCoordinateMessage
            return
        }
        if let last = points.last,
           last.distance(to: coordinate) < RouteGeometry.duplicateDistanceThreshold {
            return
        }
        points.append(coordinate)
        errorMessage = nil
    }

    func undoLastPoint() {
        guard !points.isEmpty else {
            return
        }
        points.removeLast()
        errorMessage = nil
    }

    /// Drops the points but keeps the name and the closed-loop switch.
    func clear() {
        points.removeAll()
        errorMessage = nil
    }

    // MARK: - Saving

    /// Builds the route to store. `existing` supplies the identity when editing; a new route gets a
    /// fresh id and `.drawn` source. Stored points are the collapsed vertices only — closure is
    /// carried by `isClosed`, never by a duplicated first point.
    func makeRoute(existing: RouteDefinition? = nil) throws -> RouteDefinition {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = Self.emptyNameMessage
            throw RouteEditorError.emptyName
        }
        name = trimmedName

        let geometry: RouteGeometry
        do {
            geometry = try RouteGeometry(points: points, isClosed: isClosed)
        } catch {
            errorMessage = geometryMessage(for: error)
            throw error
        }

        let storedPoints = isClosed ? Array(geometry.points.dropLast()) : geometry.points
        errorMessage = nil
        return RouteDefinition(
            id: existing?.id ?? UUID(),
            name: trimmedName,
            points: storedPoints,
            isClosed: isClosed,
            source: existing?.source ?? .drawn,
            createdAt: existing?.createdAt ?? Date.now,
            updatedAt: Date.now
        )
    }

    // MARK: - Geometry agreement

    private var temporaryGeometry: RouteGeometry? {
        do {
            return try RouteGeometry(points: points, isClosed: isClosed)
        } catch {
            // Points or length are still short of a route: that is exactly `canSave == false`.
            return nil
        }
    }

    private static func effectivePoints(
        in points: [GeoCoordinate],
        isClosed: Bool
    ) -> [GeoCoordinate] {
        let collapsed = points.reduce(into: [GeoCoordinate]()) { result, point in
            guard let previous = result.last else {
                result.append(point)
                return
            }
            if previous.distance(to: point) >= RouteGeometry.duplicateDistanceThreshold {
                result.append(point)
            }
        }
        guard isClosed, collapsed.count > 1, let first = collapsed.first, let last = collapsed.last,
              last.distance(to: first) < RouteGeometry.duplicateDistanceThreshold else {
            return collapsed
        }
        return Array(collapsed.dropLast())
    }

    private var minimumPointMessage: String {
        isClosed ? Self.closedRouteMinimumMessage : Self.openRouteMinimumMessage
    }

    /// Maps a geometry failure to display text while the original error keeps travelling to the caller.
    private func geometryMessage(for error: Error) -> String {
        guard let geometryError = error as? RouteGeometryError else {
            return Self.genericGeometryMessage
        }
        switch geometryError {
        case .invalidCoordinate:
            return Self.invalidCoordinateMessage
        case .tooFewPoints:
            return minimumPointMessage
        case .zeroLength:
            // A closed draft with one effective point surfaces as `.zeroLength` but really lacks points.
            return effectivePointCount < (isClosed ? 3 : 2) ? minimumPointMessage : Self.zeroLengthMessage
        }
    }

    // MARK: - Messages

    private static let defaultName = "New Route"
    private static let emptyNameMessage = "Route name cannot be empty."
    private static let invalidCoordinateMessage = "Point is outside valid coordinates."
    private static let openRouteMinimumMessage = "A route needs at least 2 points."
    private static let closedRouteMinimumMessage = "A closed route needs at least 3 points."
    private static let zeroLengthMessage = "A route must have a non-zero length."
    private static let genericGeometryMessage = "The route could not be built."
}
