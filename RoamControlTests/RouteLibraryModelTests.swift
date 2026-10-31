import XCTest
@testable import RoamControl

@MainActor
final class RouteLibraryModelTests: XCTestCase {
    /// Whole-second timestamps only: the ISO-8601 strategy drops sub-second precision.
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixtures

    /// Every test gets its own directory. The store file sits one level down so a test can turn
    /// its parent into a regular file and make directory creation fail.
    private func makeStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RouteLibraryModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        }
        return directory
            .appendingPathComponent("library", isDirectory: true)
            .appendingPathComponent("routes.json", isDirectory: false)
    }

    private func makeModel(storeURL: URL) -> RouteLibraryModel {
        RouteLibraryModel(store: RouteStore(fileURL: storeURL))
    }

    private func makeRoute(
        id: UUID = UUID(),
        name: String,
        updatedAt: Date,
        points: [GeoCoordinate] = [
            GeoCoordinate(latitude: 31.2304, longitude: 121.4737),
            GeoCoordinate(latitude: 31.2314, longitude: 121.4747)
        ],
        createdAt creationDate: Date? = nil
    ) -> RouteDefinition {
        RouteDefinition(
            id: id,
            name: name,
            points: points,
            isClosed: false,
            source: .drawn,
            createdAt: creationDate ?? createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Load

    func testLoadSortsRoutesByUpdatedAtDescending() throws {
        let storeURL = try makeStoreURL()
        let oldest = makeRoute(name: "Oldest", updatedAt: createdAt)
        let middle = makeRoute(name: "Middle", updatedAt: createdAt.addingTimeInterval(300))
        let newest = makeRoute(name: "Newest", updatedAt: createdAt.addingTimeInterval(600))
        try RouteStore(fileURL: storeURL).save([middle, oldest, newest])

        let model = makeModel(storeURL: storeURL)

        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.routes.count, 3)
        XCTAssertEqual(model.routes.map(\.name), ["Newest", "Middle", "Oldest"])
    }

    func testLoadBreaksUpdatedAtTiesByIdentifier() throws {
        let storeURL = try makeStoreURL()
        let lowerID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-0000000000AA"))
        let higherID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-0000000000BB"))
        let tie = createdAt.addingTimeInterval(300)
        let higher = makeRoute(id: higherID, name: "Higher ID", updatedAt: tie)
        let lower = makeRoute(id: lowerID, name: "Lower ID", updatedAt: tie)
        try RouteStore(fileURL: storeURL).save([higher, lower])

        let first = makeModel(storeURL: storeURL)
        let second = makeModel(storeURL: storeURL)

        XCTAssertEqual(first.routes.map(\.id), [lowerID, higherID])
        XCTAssertEqual(second.routes.map(\.id), first.routes.map(\.id))
    }

    // MARK: - Upsert

    func testUpsertAddsAndReplacesByStableID() throws {
        let storeURL = try makeStoreURL()
        let model = makeModel(storeURL: storeURL)
        XCTAssertEqual(model.routes, [])

        let original = makeRoute(name: "Morning loop", updatedAt: createdAt.addingTimeInterval(60))
        model.upsert(original)

        XCTAssertEqual(model.routes.count, 1)
        XCTAssertNil(model.errorMessage)

        let editedPoints = [
            GeoCoordinate(latitude: 31.2404, longitude: 121.4737),
            GeoCoordinate(latitude: 31.2414, longitude: 121.4747)
        ]
        let edited = RouteDefinition(
            id: original.id,
            name: "Morning loop v2",
            points: editedPoints,
            isClosed: true,
            source: .gpx,
            createdAt: original.createdAt,
            updatedAt: createdAt.addingTimeInterval(600)
        )
        model.upsert(edited)

        XCTAssertEqual(model.routes.count, 1)
        let stored = try XCTUnwrap(model.route(id: original.id))
        XCTAssertEqual(stored.id, original.id)
        XCTAssertEqual(stored.createdAt, original.createdAt)
        XCTAssertEqual(stored.name, "Morning loop v2")
        XCTAssertEqual(stored.points, editedPoints)
        XCTAssertTrue(stored.isClosed)
        XCTAssertEqual(stored.source, .gpx)
        XCTAssertEqual(stored.updatedAt, edited.updatedAt)

        let reloaded = try RouteStore(fileURL: storeURL).load()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.name, "Morning loop v2")

        let second = makeRoute(name: "Evening loop", updatedAt: createdAt.addingTimeInterval(700))
        model.upsert(second)

        XCTAssertEqual(model.routes.map(\.name), ["Evening loop", "Morning loop v2"])
        XCTAssertEqual(Set(model.routes.map(\.id)), Set([original.id, second.id]))
    }

    func testUpsertTrimsNameAndRejectsEmptyName() throws {
        let storeURL = try makeStoreURL()
        let model = makeModel(storeURL: storeURL)
        let route = makeRoute(name: "  Riverside loop \n", updatedAt: createdAt.addingTimeInterval(60))

        model.upsert(route)

        XCTAssertEqual(model.routes.count, 1)
        XCTAssertEqual(try XCTUnwrap(model.route(id: route.id)).name, "Riverside loop")
        XCTAssertEqual(try RouteStore(fileURL: storeURL).load().first?.name, "Riverside loop")

        let savedIDs = model.routes.map(\.id)
        let blank = makeRoute(name: "   \n\t  ", updatedAt: createdAt.addingTimeInterval(120))
        model.upsert(blank)

        XCTAssertEqual(model.errorMessage, "Route name cannot be empty.")
        XCTAssertEqual(model.routes.map(\.id), savedIDs)
        XCTAssertNil(model.route(id: blank.id))
        XCTAssertEqual(try RouteStore(fileURL: storeURL).load().count, 1)
    }

    // MARK: - Name validation

    func testNormalizedNameRejectsEmptyName() {
        XCTAssertNil(RouteNameValidator.normalizedName(from: ""))
    }

    func testNormalizedNameRejectsWhitespaceAndNewlines() {
        XCTAssertNil(RouteNameValidator.normalizedName(from: " \n\t\r "))
    }

    func testNormalizedNameAcceptsOrdinaryName() {
        XCTAssertEqual(RouteNameValidator.normalizedName(from: "神秘"), "神秘")
    }

    func testNormalizedNameTrimsSurroundingWhitespace() {
        XCTAssertEqual(RouteNameValidator.normalizedName(from: "  Riverside loop \n"), "Riverside loop")
    }

    // MARK: - Delete

    func testDeleteRemovesOnlyRequestedRoute() throws {
        let storeURL = try makeStoreURL()
        let keep = makeRoute(name: "Keep", updatedAt: createdAt.addingTimeInterval(60))
        let remove = makeRoute(name: "Remove", updatedAt: createdAt.addingTimeInterval(120))
        let alsoKeep = makeRoute(name: "Also keep", updatedAt: createdAt.addingTimeInterval(180))
        try RouteStore(fileURL: storeURL).save([keep, remove, alsoKeep])

        let model = makeModel(storeURL: storeURL)
        XCTAssertEqual(model.routes.count, 3)

        model.delete(id: remove.id)

        XCTAssertEqual(model.routes.map(\.id), [alsoKeep.id, keep.id])
        XCTAssertNil(model.errorMessage)
        let reloaded = try RouteStore(fileURL: storeURL).load()
        XCTAssertEqual(reloaded.map(\.id), [alsoKeep.id, keep.id])
    }

    func testDeleteOfUnknownIdentifierLeavesFileAndStateAlone() throws {
        let storeURL = try makeStoreURL()
        let route = makeRoute(name: "Only loop", updatedAt: createdAt.addingTimeInterval(60))
        try RouteStore(fileURL: storeURL).save([route])
        let model = makeModel(storeURL: storeURL)
        let fileBefore = try Data(contentsOf: storeURL)

        model.delete(id: UUID())

        XCTAssertEqual(model.routes.map(\.id), [route.id])
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(try Data(contentsOf: storeURL), fileBefore)
    }

    // MARK: - Failures

    func testFailedSaveKeepsPreviousInMemoryState() throws {
        let storeURL = try makeStoreURL()
        let existing = makeRoute(name: "Saved loop", updatedAt: createdAt.addingTimeInterval(60))
        try RouteStore(fileURL: storeURL).save([existing])

        let model = makeModel(storeURL: storeURL)
        let loadedRoutes = model.routes
        XCTAssertEqual(loadedRoutes.count, 1)

        // A regular file where the parent directory belongs makes createDirectory fail.
        let parentURL = storeURL.deletingLastPathComponent()
        try FileManager.default.removeItem(at: parentURL)
        try Data("not a directory".utf8).write(to: parentURL)

        model.upsert(makeRoute(name: "Doomed loop", updatedAt: createdAt.addingTimeInterval(600)))

        XCTAssertEqual(model.routes, loadedRoutes)
        XCTAssertEqual(model.errorMessage, "Could not save routes.")
    }

    func testDeleteFailureKeepsPreviousInMemoryState() throws {
        let storeURL = try makeStoreURL()
        let existing = makeRoute(name: "Saved loop", updatedAt: createdAt.addingTimeInterval(60))
        try RouteStore(fileURL: storeURL).save([existing])
        let model = makeModel(storeURL: storeURL)

        let parentURL = storeURL.deletingLastPathComponent()
        try FileManager.default.removeItem(at: parentURL)
        try Data("not a directory".utf8).write(to: parentURL)

        model.delete(id: existing.id)

        XCTAssertEqual(model.routes.map(\.id), [existing.id])
        XCTAssertEqual(model.errorMessage, "Could not save routes.")
    }

    func testCorruptedStoreExposesErrorWithoutClearingRoutes() throws {
        let storeURL = try makeStoreURL()

        // 1. Corrupted before first load: empty routes, visible error.
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{ \"schemaVersion\": ".utf8).write(to: storeURL)
        let fresh = makeModel(storeURL: storeURL)

        XCTAssertEqual(fresh.routes, [])
        XCTAssertFalse(fresh.errorMessage?.isEmpty ?? true)
        XCTAssertEqual(fresh.errorMessage, "Routes file is corrupted.")

        // 2. Good load first, then corruption: the previous array survives.
        let valid = makeRoute(name: "Recovered loop", updatedAt: createdAt.addingTimeInterval(60))
        try RouteStore(fileURL: storeURL).save([valid])
        let model = makeModel(storeURL: storeURL)
        let loadedRoutes = model.routes
        XCTAssertEqual(loadedRoutes.count, 1)
        XCTAssertNil(model.errorMessage)

        let corrupted = Data("[]".utf8)
        try corrupted.write(to: storeURL)
        model.load()

        XCTAssertEqual(model.routes, loadedRoutes)
        XCTAssertEqual(model.errorMessage, "Routes file is corrupted.")
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(try Data(contentsOf: storeURL), corrupted)
    }

    func testUnsupportedSchemaMessageNamesVersion() throws {
        let storeURL = try makeStoreURL()
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let document = Data("{\"schemaVersion\":2,\"routes\":[]}".utf8)
        try document.write(to: storeURL)

        let model = makeModel(storeURL: storeURL)

        XCTAssertEqual(model.routes, [])
        XCTAssertEqual(model.errorMessage, "Routes file uses unsupported schema version 2.")
        XCTAssertEqual(try Data(contentsOf: storeURL), document)
    }

    // MARK: - Accessors

    func testSuccessfulOperationsClearPreviousError() throws {
        let storeURL = try makeStoreURL()
        let model = makeModel(storeURL: storeURL)

        model.upsert(makeRoute(name: "   ", updatedAt: createdAt))
        XCTAssertEqual(model.errorMessage, "Route name cannot be empty.")

        let route = makeRoute(name: "Clearing loop", updatedAt: createdAt.addingTimeInterval(60))
        model.upsert(route)
        XCTAssertNil(model.errorMessage)

        model.delete(id: route.id)
        XCTAssertTrue(model.routes.isEmpty)
        XCTAssertNil(model.errorMessage)
    }

    func testRouteLookupAndClearError() throws {
        let storeURL = try makeStoreURL()
        let route = makeRoute(name: "Lookup loop", updatedAt: createdAt.addingTimeInterval(60))
        try RouteStore(fileURL: storeURL).save([route])
        let model = makeModel(storeURL: storeURL)

        XCTAssertEqual(model.route(id: route.id)?.name, "Lookup loop")
        XCTAssertNil(model.route(id: UUID()))

        model.upsert(makeRoute(name: "", updatedAt: createdAt))
        XCTAssertEqual(model.errorMessage, "Route name cannot be empty.")

        model.clearError()

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.routes.map(\.id), [route.id])
    }
}
