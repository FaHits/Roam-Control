#if DEBUG
import CoreLocation
import Observation

/// Debug-only readback of what the device reports after a probe injection.
@MainActor
@Observable
final class DeviceLocationProbe: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var reading: CLLocation?
    private(set) var failure: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestReading() {
        failure = nil
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.reading = location }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.failure = text }
    }
}
#endif
