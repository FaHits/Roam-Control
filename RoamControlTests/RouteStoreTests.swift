import XCTest
@testable import RoamControl

final class RouteStoreTests: XCTestCase {
    private var directoryURL: URL!

    /// Whole-second timestamps only: the ISO-8601 strategy drops sub-second precision.
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let updatedAt = Date(timeIntervalSince1970: 1_700_000_600)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RouteStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directoryURL, FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Missing file

    func testMissingFileLoadsAsEmptyLibrary() throws {
        let store = RouteStore(fileURL: directoryURL.appendingPathComponent("routes.json"))

        XCTAssertEqual(try store.load(), [])
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: directoryURL.path),
            "load must not create the directory or the file"
        )
    }

    // MARK: - Round trip

    func testSaveAndLoadRoundTripsRoutes() throws {
        let fileURL = directoryURL.appendingPathComponent("routes.json")
        let openRoute = RouteDefinition(
            id: UUID(),
            name: "Riverside out and back",
            points: [
                GeoCoordinate(latitude: 31.2304, longitude: 121.4737),
                GeoCoordinate(latitude: 31.2314, longitude: 121.4747),
                GeoCoordinate(latitude: 31.2324, longitude: 121.4737)
            ],
            isClosed: false,
            source: .gpx,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let closedRoute = RouteDefinition(
            id: UUID(),
            name: "Block loop",
            points: [
                GeoCoordinate(latitude: 31.2304, longitude: 121.4737),
                GeoCoordinate(latitude: 31.2304, longitude: 121.4747),
                GeoCoordinate(latitude: 31.2314, longitude: 121.4747),
                GeoCoordinate(latitude: 31.2314, longitude: 121.4737)
            ],
            isClosed: true,
            source: .drawn,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        try RouteStore(fileURL: fileURL).save([openRoute, closedRoute])
        let loaded = try RouteStore(fileURL: fileURL).load()

        assertRoutesMatch(loaded, [openRoute, closedRoute])
        XCTAssertFalse(loaded[0].isClosed)
        XCTAssertTrue(loaded[1].isClosed)
    }

    // MARK: - Parent directory

    func testSaveCreatesParentDirectory() throws {
        let nestedDirectory = directoryURL
            .appendingPathComponent("route", isDirectory: true)
            .appendingPathComponent("library", isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
        let fileURL = nestedDirectory.appendingPathComponent("routes.json")
        let route = makeDrawnRoute(name: "Nested")

        try RouteStore(fileURL: fileURL).save([route])

        var isDirectory: ObjCBool = false
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: nestedDirectory.path, isDirectory: &isDirectory)
        )
        XCTAssertTrue(isDirectory.boolValue)
        assertRoutesMatch(try RouteStore(fileURL: fileURL).load(), [route])
    }

    // MARK: - Corrupted file

    func testCorruptedFileThrowsAndRemainsUnchanged() throws {
        let fileURL = directoryURL.appendingPathComponent("routes.json")
        let store = RouteStore(fileURL: fileURL)
        let fixtures = [
            // Truncated JSON: syntax error.
            "{\"schemaVersion\": 1, \"routes\": [",
            // Missing fields on the route.
            "{\"schemaVersion\": 1, \"routes\": [{\"id\": \"6F9619FF-8B86-D011-B42D-00C04FC964FF\", \"name\": \"Half\"}]}",
            // Wrong type for routes.
            "{\"schemaVersion\": 1, \"routes\": \"not an array\"}",
            // Valid shape, invalid ISO-8601 date.
            """
            {"schemaVersion": 1, "routes": [{"createdAt": "2026-13-45T99:99:99Z", \
            "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "isClosed": false, "name": "Bad date", \
            "points": [{"latitude": 31.2304, "longitude": 121.4737}], "source": "drawn", \
            "updatedAt": "2026-10-30T13:38:33Z"}]}
            """
        ]

        for fixture in fixtures {
            try write(fixture, to: fileURL)
            let originalBytes = try Data(contentsOf: fileURL)

            XCTAssertEqual(
                errorThrown(by: { _ = try store.load() }),
                .corruptedFile,
                "fixture should be reported as corrupted: \(fixture)"
            )
            XCTAssertEqual(
                try Data(contentsOf: fileURL),
                originalBytes,
                "load must not rewrite a corrupted file"
            )
        }
    }

    // MARK: - Unsupported schema

    func testUnsupportedSchemaThrows() throws {
        let fileURL = directoryURL.appendingPathComponent("routes.json")
        let document = "{\"schemaVersion\": 2, \"routes\": []}"
        try write(document, to: fileURL)
        let originalBytes = try Data(contentsOf: fileURL)

        XCTAssertEqual(
            errorThrown(by: { _ = try RouteStore(fileURL: fileURL).load() }),
            .unsupportedSchema(2)
        )
        XCTAssertEqual(try Data(contentsOf: fileURL), originalBytes)
    }

    // MARK: - Atomic replacement

    func testSaveUsesAtomicReplacement() throws {
        let fileURL = directoryURL.appendingPathComponent("routes.json")
        let store = RouteStore(fileURL: fileURL)
        let replaced = makeDrawnRoute(name: "Replaced", isClosed: false)
        try store.save([replaced])

        let freshRoutes = [
            makeDrawnRoute(name: "First lap", isClosed: true),
            makeDrawnRoute(name: "Second lap", isClosed: true)
        ]
        try store.save(freshRoutes)

        let loaded = try RouteStore(fileURL: fileURL).load()
        assertRoutesMatch(loaded, freshRoutes)
        XCTAssertFalse(loaded.contains { $0.id == replaced.id }, "old route must not survive")

        let entries = try FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
        XCTAssertEqual(entries, ["routes.json"], "atomic write must not leave temporary files")
    }

    // MARK: - Empty library

    func testSaveAndLoadEmptyLibrary() throws {
        let fileURL = directoryURL.appendingPathComponent("routes.json")
        try RouteStore(fileURL: fileURL).save([])

        XCTAssertEqual(try RouteStore(fileURL: fileURL).load(), [])

        let object = try JSONSerialization.jsonObject(with: try Data(contentsOf: fileURL))
        let document = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(document["schemaVersion"] as? Int, RouteStore.currentSchemaVersion)
        XCTAssertEqual((document["routes"] as? [Any])?.count, 0)
    }

    // MARK: - Live location

    func testLiveFileURLPointsAtRoutesJSON() {
        XCTAssertEqual(
            Array(RouteStore.liveFileURL.pathComponents.suffix(2)),
            ["RoamControl", "routes.json"]
        )
    }

    // MARK: - Helpers

    private func makeDrawnRoute(name: String, isClosed: Bool = true) -> RouteDefinition {
        RouteDefinition(
            id: UUID(),
            name: name,
            points: [
                GeoCoordinate(latitude: 31.2304, longitude: 121.4737),
                GeoCoordinate(latitude: 31.2304, longitude: 121.4747),
                GeoCoordinate(latitude: 31.2314, longitude: 121.4747)
            ],
            isClosed: isClosed,
            source: .drawn,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }

    private func errorThrown(by body: () throws -> Void) -> RouteStoreError? {
        do {
            try body()
            return nil
        } catch {
            return error as? RouteStoreError
        }
    }

    private func assertRoutesMatch(
        _ actual: [RouteDefinition],
        _ expected: [RouteDefinition],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        guard actual.count == expected.count else { return }

        for (actualRoute, expectedRoute) in zip(actual, expected) {
            XCTAssertEqual(actualRoute.id, expectedRoute.id, file: file, line: line)
            XCTAssertEqual(actualRoute.name, expectedRoute.name, file: file, line: line)
            XCTAssertEqual(actualRoute.isClosed, expectedRoute.isClosed, file: file, line: line)
            XCTAssertEqual(actualRoute.source, expectedRoute.source, file: file, line: line)
            XCTAssertEqual(actualRoute.createdAt, expectedRoute.createdAt, file: file, line: line)
            XCTAssertEqual(actualRoute.updatedAt, expectedRoute.updatedAt, file: file, line: line)
            XCTAssertEqual(
                actualRoute.points.count,
                expectedRoute.points.count,
                file: file,
                line: line
            )
            for (actualPoint, expectedPoint) in zip(actualRoute.points, expectedRoute.points) {
                XCTAssertEqual(actualPoint.latitude, expectedPoint.latitude, file: file, line: line)
                XCTAssertEqual(actualPoint.longitude, expectedPoint.longitude, file: file, line: line)
            }
        }
    }
}
