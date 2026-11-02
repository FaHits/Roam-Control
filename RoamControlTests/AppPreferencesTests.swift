import XCTest
@testable import RoamControl

@MainActor
final class AppPreferencesTests: XCTestCase {
    private let suiteName = "AppPreferencesTests.\(UUID().uuidString)"
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
        AppModel(pairingService: AppPreferencesStubPairingService(), preferences: preferences)
    }

    func testOverseasPlaceSearchDefaultsToDisabled() {
        XCTAssertFalse(makeAppModel().overseasPlaceSearchEnabled)
    }

    func testOverseasPlaceSearchPersistsAcrossInstances() {
        let appModel = makeAppModel()
        appModel.setOverseasPlaceSearchEnabled(true)

        XCTAssertTrue(appModel.overseasPlaceSearchEnabled)
        XCTAssertTrue(preferences.bool(forKey: "overseasPlaceSearchEnabled"))
        XCTAssertTrue(makeAppModel().overseasPlaceSearchEnabled)

        appModel.setOverseasPlaceSearchEnabled(false)

        XCTAssertFalse(preferences.bool(forKey: "overseasPlaceSearchEnabled"))
        XCTAssertFalse(makeAppModel().overseasPlaceSearchEnabled)
    }
}

private struct AppPreferencesStubPairingService: PairingService {
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
