import CoreLocation
import XCTest
@testable import RoamControl

@MainActor
final class DeviceInjectionBoundaryTests: XCTestCase {
    func testAdapterOutputIsWhatReachesTheDevice() {
        let coordinator = LocalDeviceSessionCoordinator()
        coordinator.coordinateAdapter = DeviceCoordinateAdapter(conversion: .wgs84ToGCJ02)

        let target = LocationTarget(
            name: "Tiananmen",
            subtitle: "",
            latitude: 39.908722,
            longitude: 116.397499
        )
        let injected = coordinator.injectedCoordinate(for: target)

        XCTAssertEqual(injected.latitude, 39.91012550007891, accuracy: 1e-6)
        XCTAssertEqual(injected.longitude, 116.4037425752605, accuracy: 1e-6)
        XCTAssertNotEqual(injected.latitude, target.latitude)
    }

    func testNoneAdapterPassesRawThrough() {
        let coordinator = LocalDeviceSessionCoordinator()
        coordinator.coordinateAdapter = DeviceCoordinateAdapter(conversion: .none)

        let target = LocationTarget(name: "Tokyo", subtitle: "", latitude: 35.681236, longitude: 139.767125)
        let injected = coordinator.injectedCoordinate(for: target)

        XCTAssertEqual(injected.latitude, target.latitude)
        XCTAssertEqual(injected.longitude, target.longitude)
    }

    func testInjectionDoesNotMutateTheTarget() {
        let coordinator = LocalDeviceSessionCoordinator()
        coordinator.coordinateAdapter = DeviceCoordinateAdapter(conversion: .gcj02ToWGS84)

        let target = LocationTarget(
            name: "Track",
            subtitle: "",
            latitude: 21.25601589175258,
            longitude: 110.30687415389694
        )
        _ = coordinator.injectedCoordinate(for: target)

        XCTAssertEqual(target.latitude, 21.25601589175258)
        XCTAssertEqual(target.longitude, 110.30687415389694)
    }

    func testLiveAdapterUsesMeasuredDirection() {
        XCTAssertEqual(DeviceCoordinateAdapter.live.conversion, .gcj02ToWGS84)
    }

    func testBothFFICallSitesUseTheAdapterOutput() throws {
        let source = try Self.sourceFile("RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift")

        XCTAssertTrue(
            source.contains("rc_location_session_update(activeSession, injected.latitude, injected.longitude)"),
            "The update FFI call must pass adapter output."
        )
        XCTAssertTrue(
            source.contains("injectedLatitude,") && source.contains("injectedLongitude,"),
            "The run FFI call must pass adapter output."
        )
        XCTAssertFalse(
            source.contains("activeSession, target.latitude"),
            "The update FFI call must never pass the raw target."
        )
        XCTAssertGreaterThanOrEqual(
            source.components(separatedBy: "injectedCoordinate(for: target)").count - 1,
            2,
            "Both injection points must route through injectedCoordinate(for:)."
        )
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }
}
