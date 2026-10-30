import XCTest
@testable import RoamControl

@MainActor
final class RouteEditorModelTests: XCTestCase {
    /// Real coordinates near Shanghai; every fixture distance is measured with `GeoCoordinate.distance`.
    private let base = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)
    private let invalidCoordinateMessage = "Point is outside valid coordinates."
    private let emptyNameMessage = "Route name cannot be empty."

    // MARK: - Fixtures

    /// Builds a point by metric offset from `base`; latitude and longitude get their own scale at 31°.
    private func point(north: Double = 0, east: Double = 0) -> GeoCoordinate {
        GeoCoordinate(
            latitude: base.latitude + north / 111_320.0,
            longitude: base.longitude + east / (111_320.0 * cos(base.latitude * .pi / 180))
        )
    }

    private func nearPoint() -> GeoCoordinate {
        point(north: 0.2)
    }

    private func makeRoute(
        name: String = "Stored Route",
        points: [GeoCoordinate],
        isClosed: Bool,
        source: RouteSource = .drawn,
        id: UUID = UUID(),
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date? = nil
    ) -> RouteDefinition {
        RouteDefinition(
            id: id,
            name: name,
            points: points,
            isClosed: isClosed,
            source: source,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt
        )
    }

    private func makeThreePointEditor(isClosed: Bool) -> RouteEditorModel {
        let model = RouteEditorModel()
        model.isClosed = isClosed
        model.appendPoint(point(north: 0))
        model.appendPoint(point(north: 30))
        model.appendPoint(point(north: 30, east: 30))
        return model
    }

    // MARK: - Initial state

    func testNewEditorStartsWithClosedModeAndDefaultName() {
        let model = RouteEditorModel()

        XCTAssertEqual(model.name, "New Route")
        XCTAssertTrue(model.isClosed)
        XCTAssertEqual(model.points, [])
        XCTAssertFalse(model.canSave)
        XCTAssertEqual(model.effectivePointCount, 0)
        XCTAssertEqual(model.totalDistance, 0)
        XCTAssertFalse(model.canUndo)
        XCTAssertNil(model.errorMessage)
    }

    func testEditingInitializesFromRouteWithoutLosingFields() {
        let points = [point(north: 0), point(north: 30), point(north: 30, east: 30)]
        let existing = makeRoute(points: points, isClosed: true, source: .gpx)

        let model = RouteEditorModel(route: existing)

        XCTAssertEqual(model.name, "Stored Route")
        XCTAssertEqual(model.points, points)
        XCTAssertTrue(model.isClosed)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.canSave)
    }

    // MARK: - Appending

    func testAppendPointIgnoresConsecutivePointsCloserThanHalfMetre() {
        let model = RouteEditorModel()
        let first = point(north: 0)
        model.appendPoint(first)
        XCTAssertEqual(model.points.count, 1)

        let close = nearPoint()
        XCTAssertLessThan(first.distance(to: close), RouteGeometry.duplicateDistanceThreshold)
        model.appendPoint(close)
        XCTAssertEqual(model.points.count, 1)
        XCTAssertNil(model.errorMessage)

        let far = point(north: 30)
        XCTAssertGreaterThanOrEqual(first.distance(to: far), RouteGeometry.duplicateDistanceThreshold)
        model.appendPoint(far)
        XCTAssertEqual(model.points.count, 2)
        XCTAssertEqual(model.points.last, far)
    }

    func testAppendPointRejectsInvalidCoordinates() {
        let model = RouteEditorModel()

        model.appendPoint(GeoCoordinate(latitude: .nan, longitude: base.longitude))
        XCTAssertEqual(model.points, [])
        XCTAssertEqual(model.errorMessage, invalidCoordinateMessage)

        model.appendPoint(GeoCoordinate(latitude: 91, longitude: base.longitude))
        XCTAssertEqual(model.points, [])
        XCTAssertEqual(model.errorMessage, invalidCoordinateMessage)

        model.appendPoint(GeoCoordinate(latitude: base.latitude, longitude: 181))
        XCTAssertEqual(model.points, [])
        XCTAssertEqual(model.errorMessage, invalidCoordinateMessage)
    }

    func testDuplicatePointRejectionKeepsExistingError() {
        let model = RouteEditorModel()
        model.appendPoint(point(north: 0))
        model.appendPoint(GeoCoordinate(latitude: 91, longitude: base.longitude))
        XCTAssertEqual(model.errorMessage, invalidCoordinateMessage)

        model.appendPoint(nearPoint())

        XCTAssertEqual(model.points.count, 1)
        XCTAssertEqual(model.errorMessage, invalidCoordinateMessage)
    }

    func testAppendAfterInvalidCoordinateClearsError() {
        let model = RouteEditorModel()
        model.appendPoint(GeoCoordinate(latitude: 91, longitude: base.longitude))
        XCTAssertNotNil(model.errorMessage)

        model.appendPoint(point(north: 0))

        XCTAssertEqual(model.points.count, 1)
        XCTAssertNil(model.errorMessage)
    }

    // MARK: - Undo and clear

    func testUndoRemovesOnlyLastPoint() {
        let model = makeThreePointEditor(isClosed: true)
        let first = model.points[0]
        let second = model.points[1]

        model.undoLastPoint()

        XCTAssertEqual(model.points, [first, second])
        XCTAssertTrue(model.canUndo)
        XCTAssertNil(model.errorMessage)

        model.undoLastPoint()
        model.undoLastPoint()
        model.undoLastPoint()

        XCTAssertEqual(model.points, [])
        XCTAssertFalse(model.canUndo)
    }

    func testUndoClearsError() {
        let model = RouteEditorModel()
        model.appendPoint(point(north: 0))
        model.appendPoint(GeoCoordinate(latitude: -91, longitude: base.longitude))
        XCTAssertNotNil(model.errorMessage)

        model.undoLastPoint()

        XCTAssertEqual(model.points, [])
        XCTAssertNil(model.errorMessage)
    }

    func testClearRemovesAllPoints() {
        let model = makeThreePointEditor(isClosed: true)
        model.appendPoint(GeoCoordinate(latitude: 91, longitude: base.longitude))
        XCTAssertNotNil(model.errorMessage)
        let nameBefore = model.name
        let isClosedBefore = model.isClosed

        model.clear()

        XCTAssertEqual(model.points, [])
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.canSave)
        XCTAssertEqual(model.effectivePointCount, 0)
        XCTAssertEqual(model.name, nameBefore)
        XCTAssertEqual(model.isClosed, isClosedBefore)
        XCTAssertNil(model.errorMessage)
    }

    // MARK: - Derived save state

    func testCanSaveRequiresMinimumEffectivePoints() {
        let model = RouteEditorModel()
        model.isClosed = false

        model.appendPoint(point(north: 0))
        XCTAssertEqual(model.effectivePointCount, 1)
        XCTAssertFalse(model.canSave)

        model.appendPoint(point(north: 30))
        XCTAssertEqual(model.effectivePointCount, 2)
        XCTAssertTrue(model.canSave)
        XCTAssertGreaterThan(model.totalDistance, 0)
    }

    func testClosedRouteRequiresThreeEffectivePoints() {
        let model = RouteEditorModel()
        model.appendPoint(point(north: 0))
        model.appendPoint(point(north: 30))
        XCTAssertEqual(model.effectivePointCount, 2)
        XCTAssertFalse(model.canSave)

        model.appendPoint(point(north: 30, east: 30))
        XCTAssertEqual(model.effectivePointCount, 3)
        XCTAssertTrue(model.canSave)
        XCTAssertGreaterThan(model.totalDistance, 0)
    }

    /// Task 8 acceptance: a saved route needs a name, so the editor must not enable saving without one.
    func testCanSaveRequiresNonBlankName() {
        let model = makeThreePointEditor(isClosed: true)
        XCTAssertEqual(model.effectivePointCount, 3)
        XCTAssertTrue(model.canSave)

        model.name = ""
        XCTAssertFalse(model.canSave)

        model.name = "   \n"
        XCTAssertFalse(model.canSave)
    }

    func testCanSaveRecoversAfterNameIsRestored() {
        let model = makeThreePointEditor(isClosed: true)
        model.name = "Riverside loop"
        XCTAssertTrue(model.canSave)

        model.name = ""
        XCTAssertFalse(model.canSave)

        model.name = "Riverside loop"
        XCTAssertTrue(model.canSave)
        XCTAssertNil(model.errorMessage)
    }

    func testEffectivePointCountCollapsesConsecutiveDuplicates() {
        let points = [point(north: 0), nearPoint(), point(north: 30), point(north: 30, east: 30)]
        let existing = makeRoute(points: points, isClosed: true)

        let model = RouteEditorModel(route: existing)

        XCTAssertEqual(model.points.count, 4)
        XCTAssertEqual(model.effectivePointCount, 3)
    }

    func testClosedDistanceIncludesClosingSegment() {
        let closingPoint = point(north: 30, east: 30)
        let closedEditor = makeThreePointEditor(isClosed: true)
        let openEditor = makeThreePointEditor(isClosed: false)

        let closingSegment = closingPoint.distance(to: point(north: 0))

        XCTAssertGreaterThan(closedEditor.totalDistance, openEditor.totalDistance)
        XCTAssertEqual(
            closedEditor.totalDistance,
            openEditor.totalDistance + closingSegment,
            accuracy: 1e-9
        )
    }

    // MARK: - Saving

    func testClosedSaveStoresVerticesWithoutDuplicateClosingPoint() throws {
        let model = makeThreePointEditor(isClosed: true)
        model.name = "Riverside loop"

        let route = try model.makeRoute()

        XCTAssertTrue(route.isClosed)
        XCTAssertEqual(route.name, "Riverside loop")
        XCTAssertEqual(route.points.count, 3)
        XCTAssertEqual(route.points, model.points)
        XCTAssertNotEqual(route.points.first, route.points.last)
    }

    func testSaveCollapsesConsecutiveDuplicatePoints() throws {
        let points = [point(north: 0), nearPoint(), point(north: 30), point(north: 30, east: 30)]
        let existing = makeRoute(points: points, isClosed: true)
        let model = RouteEditorModel(route: existing)

        let route = try model.makeRoute(existing: existing)

        XCTAssertEqual(route.points.count, 3)
        XCTAssertNotEqual(route.points.first, route.points.last)
    }

    func testSavePreservesExistingIDAndCreationDate() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let identifier = UUID()
        let initial = makeRoute(
            points: [point(north: 0), point(north: 30)],
            isClosed: false,
            id: identifier,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let model = RouteEditorModel(route: initial)

        let before = Date.now
        let saved = try model.makeRoute(existing: initial)

        XCTAssertEqual(saved.id, identifier)
        XCTAssertEqual(saved.createdAt, createdAt)
        XCTAssertGreaterThan(saved.updatedAt, createdAt)
        XCTAssertGreaterThanOrEqual(saved.updatedAt, before)
    }

    func testSavePreservesImportedSource() throws {
        for source in [RouteSource.gpx, RouteSource.appleMaps] {
            let initial = makeRoute(
                points: [point(north: 0), point(north: 30)],
                isClosed: false,
                source: source
            )
            let model = RouteEditorModel(route: initial)

            let saved = try model.makeRoute(existing: initial)

            XCTAssertEqual(saved.source, source)
        }
    }

    func testNewRouteSaveUsesDrawnSource() throws {
        let model = RouteEditorModel()
        model.isClosed = false
        model.appendPoint(point(north: 0))
        model.appendPoint(point(north: 30))

        let first = try model.makeRoute()
        let second = try model.makeRoute()

        XCTAssertEqual(first.source, .drawn)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.points, model.points)
        XCTAssertNil(model.errorMessage)
    }

    func testSaveRejectsBlankName() {
        let model = makeThreePointEditor(isClosed: true)
        let pointsBefore = model.points
        model.name = "   \n"

        XCTAssertThrowsError(try model.makeRoute()) { error in
            XCTAssertEqual(error as? RouteEditorError, .emptyName)
        }

        XCTAssertEqual(model.errorMessage, emptyNameMessage)
        XCTAssertEqual(model.points, pointsBefore)
    }

    func testGeometryFailureThrowsAndLeavesMessage() {
        let model = RouteEditorModel()
        model.name = "Too short"
        model.appendPoint(point(north: 0))
        model.appendPoint(point(north: 30))

        XCTAssertThrowsError(try model.makeRoute()) { error in
            XCTAssertEqual(error as? RouteGeometryError, .tooFewPoints(minimum: 3))
        }

        XCTAssertEqual(model.errorMessage, "A closed route needs at least 3 points.")
    }

    func testSuccessfulSaveClearsPreviousError() throws {
        let model = makeThreePointEditor(isClosed: true)
        model.name = "  "
        XCTAssertThrowsError(try model.makeRoute())
        XCTAssertNotNil(model.errorMessage)

        model.name = "Fixed name"
        let saved = try model.makeRoute(existing: nil)

        XCTAssertEqual(saved.name, "Fixed name")
        XCTAssertNil(model.errorMessage)
    }
}
