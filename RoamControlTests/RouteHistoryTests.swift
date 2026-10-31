import XCTest
@testable import RoamControl

@MainActor
final class RouteHistoryTests: XCTestCase {
    private let start = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)

    private var target: LocationTarget {
        LocationTarget(
            name: "Riverside Loop",
            subtitle: "31.2304, 121.4737",
            latitude: start.latitude,
            longitude: start.longitude
        )
    }

    private var route: RouteDefinition {
        RouteDefinition(
            id: UUID(uuidString: "5C1B2A3D-7E4F-4A6B-9C8D-0E1F2A3B4C5D")!,
            name: "Riverside Loop",
            points: [
                start,
                GeoCoordinate(latitude: 31.2304, longitude: 121.4787),
                GeoCoordinate(latitude: 31.2334, longitude: 121.4787),
                GeoCoordinate(latitude: 31.2334, longitude: 121.4737),
            ],
            isClosed: true,
            source: .drawn,
            createdAt: Date(timeIntervalSinceReferenceDate: 770_000_000),
            updatedAt: Date(timeIntervalSinceReferenceDate: 770_000_000)
        )
    }

    private func makePairedAppModel() async -> AppModel {
        let suiteName = "RouteHistoryTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        preferences.removePersistentDomain(forName: suiteName)
        let appModel = AppModel(pairingService: PairedStubPairingService(), preferences: preferences)
        await appModel.restorePairingStatus()
        return appModel
    }

    func testStartingRouteRunDoesNotWriteLocationHistory() async throws {
        let appModel = await makePairedAppModel()
        guard case .paired = appModel.pairingStatus else {
            return XCTFail("expected a paired session, got \(appModel.pairingStatus)")
        }

        await appModel.startRouteLocationSession(
            at: target,
            route: route,
            profile: .running,
            mode: .once
        )

        XCTAssertTrue(appModel.locationHistory.isEmpty)
    }

    func testStartingFixedLocationSessionStillWritesLocationHistory() async throws {
        let appModel = await makePairedAppModel()
        guard case .paired = appModel.pairingStatus else {
            return XCTFail("expected a paired session, got \(appModel.pairingStatus)")
        }

        await appModel.startLocationSession(at: target)

        XCTAssertEqual(appModel.locationHistory.map(\.id), [target.id])
    }
}

private struct PairedStubPairingService: PairingService {
    private static let summary = PairingRecordSummary(
        identifier: "route-history-tests",
        fingerprint: "ABCDEF0123456789",
        importedAt: Date(timeIntervalSinceReferenceDate: 770_000_000)
    )

    func storedRecord() async throws -> PairingRecordSummary? { Self.summary }
    func importRecord(from url: URL) async throws -> PairingRecordSummary {
        throw PairingServiceError.corruptStoredRecord
    }
    func storeGeneratedRecord(_ data: Data, hostAltIRK: Data?) async throws -> PairingRecordSummary {
        throw PairingServiceError.corruptStoredRecord
    }
    func pairingRecordData() async throws -> Data? { nil }
    func removeRecord() async throws {}
}
