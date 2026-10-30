import Foundation
import XCTest
@testable import RoamControl

final class RouteProfileStoreTests: XCTestCase {
    func testLoadReturnsRunningWhenNothingWasSaved() {
        let (defaults, _) = makeDefaults()

        XCTAssertEqual(RunProfileStore(defaults: defaults).load(), .running)
    }

    func testSaveAndLoadRoundTripsAllProfileFields() {
        let (defaults, _) = makeDefaults()
        let profile = RunProfile(
            targetSpeedMetersPerSecond: 4.25,
            targetCadenceStepsPerMinute: 188,
            speedVariationFraction: 0.12,
            cadenceVariationFraction: 0.09,
            gpsJitterRadiusMeters: 3.5,
            noiseSeed: 0xDEC0_DE
        )
        let store = RunProfileStore(defaults: defaults)

        store.save(profile)

        XCTAssertEqual(store.load(), profile)
    }

    func testLoadFallsBackToRunningForInvalidStoredData() throws {
        let (defaults, _) = makeDefaults()
        let store = RunProfileStore(defaults: defaults)

        defaults.set(Data("not json".utf8), forKey: RunProfileStore.storageKey)
        XCTAssertEqual(store.load(), .running)

        var outOfRange = RunProfile.running
        outOfRange.targetSpeedMetersPerSecond = 100
        defaults.set(try JSONEncoder().encode(outOfRange), forKey: RunProfileStore.storageKey)
        XCTAssertEqual(store.load(), .running)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "RouteProfileStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated UserDefaults suite")
        }
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (defaults, suiteName)
    }
}
