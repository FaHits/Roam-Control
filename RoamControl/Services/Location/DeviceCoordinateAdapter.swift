import CoreLocation

enum DeviceCoordinateConversion {
    case none
    case wgs84ToGCJ02
    case gcj02ToWGS84

    var label: String {
        switch self {
        case .none: "None (raw passthrough)"
        case .wgs84ToGCJ02: "WGS-84 → GCJ-02"
        case .gcj02ToWGS84: "GCJ-02 → WGS-84"
        }
    }
}

/// The only place where the app's coordinate domain becomes the domain the
/// injected location service expects. Upstream values are never mutated.
struct DeviceCoordinateAdapter {
    let conversion: DeviceCoordinateConversion

    func coordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        switch conversion {
        case .none:
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        case .wgs84ToGCJ02:
            ChinaCoordinateTransform.wgs84ToGCJ02(latitude: latitude, longitude: longitude)
        case .gcj02ToWGS84:
            ChinaCoordinateTransform.gcj02ToWGS84(latitude: latitude, longitude: longitude)
        }
    }

    /// Phase 0: the ~500 m offset is confirmed, its direction is not.
    /// Replace `.none` with the measured case (`.wgs84ToGCJ02` or
    /// `.gcj02ToWGS84`) once on-device A/B data says which one. No runtime switch.
    static let live = DeviceCoordinateAdapter(conversion: .none)
}
