import XCTest
@testable import RoamControl

@MainActor
final class MapDisplayStyleTests: XCTestCase {
    private let suiteName = "MapDisplayStyleTests.\(UUID().uuidString)"
    private var preferences: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        preferences.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        preferences.removePersistentDomain(forName: suiteName)
        preferences = nil
        super.tearDown()
    }

    private func makeAppModel() -> AppModel {
        AppModel(pairingService: MapStyleStubPairingService(), preferences: preferences)
    }

    func testDefaultStyleIsStandardWithoutStoredValue() {
        XCTAssertEqual(makeAppModel().mapDisplayStyle, .standard)
    }

    func testStoredSatelliteStyleIsReadAtLaunch() {
        preferences.set("satellite", forKey: "mapDisplayStyle")

        XCTAssertEqual(makeAppModel().mapDisplayStyle, .satellite)
    }

    func testSettingStylePersistsRawValueAndReloads() {
        let appModel = makeAppModel()

        appModel.setMapDisplayStyle(.hybrid)

        XCTAssertEqual(appModel.mapDisplayStyle, .hybrid)
        XCTAssertEqual(preferences.string(forKey: "mapDisplayStyle"), "hybrid")
        XCTAssertEqual(makeAppModel().mapDisplayStyle, .hybrid)
    }

    func testUnknownOrEmptyStoredValueFallsBackToStandard() {
        for stored in ["terrain", ""] {
            preferences.set(stored, forKey: "mapDisplayStyle")

            XCTAssertEqual(makeAppModel().mapDisplayStyle, .standard, "stored: \(stored)")
        }
    }

    func testCasesRawValuesAndTitles() {
        XCTAssertEqual(MapDisplayStyle.allCases, [.standard, .satellite, .hybrid])
        XCTAssertEqual(MapDisplayStyle.allCases.map(\.rawValue), ["standard", "satellite", "hybrid"])
        XCTAssertTrue(MapDisplayStyle.allCases.allSatisfy { !$0.title.isEmpty })
    }
}

private struct MapStyleStubPairingService: PairingService {
    func storedRecord() async throws -> PairingRecordSummary? { nil }
    func importRecord(from url: URL) async throws -> PairingRecordSummary {
        throw PairingServiceError.corruptStoredRecord
    }
    func storeGeneratedRecord(_ data: Data, hostAltIRK: Data?) async throws -> PairingRecordSummary {
        throw PairingServiceError.corruptStoredRecord
    }
    func pairingRecordData() async throws -> Data? { nil }
    func removeRecord() async throws {}
}
