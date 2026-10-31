import CoreLocation

/// App/map coordinate domain. Datum conversion for device injection happens only
/// at the `LocalDeviceSessionCoordinator` FFI boundary, never here.
struct LocationTarget: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    var id: String {
        "\(latitude.bitPattern)-\(longitude.bitPattern)"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
