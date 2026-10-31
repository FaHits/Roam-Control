import CoreLocation

/// WGS-84 ↔ GCJ-02 conversion for mainland China.
///
/// Only the device-injection boundary uses this. Everything upstream
/// (`LocationTarget`, routes, editors, storage) keeps a single self-consistent
/// coordinate domain, so nothing here is a data migration.
enum ChinaCoordinateTransform {
    private static let semiMajorAxis = 6_378_245.0
    private static let eccentricitySquared = 0.006_693_421_622_965_943

    /// Coarse mainland-China bounding box. Outside it every datum we care about agrees.
    static func isInsideChina(latitude: Double, longitude: Double) -> Bool {
        longitude > 73.66 && longitude < 135.05 && latitude > 3.86 && latitude < 53.55
    }

    static func wgs84ToGCJ02(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        guard isInsideChina(latitude: latitude, longitude: longitude) else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        let offsets = offset(x: longitude - 105.0, y: latitude - 35.0)
        let radians = latitude / 180.0 * .pi
        let sinRadians = sin(radians)
        let magic = 1 - eccentricitySquared * sinRadians * sinRadians
        let sqrtMagic = sqrt(magic)
        let latitudeOffset = (offsets.latitude * 180.0)
            / ((semiMajorAxis * (1 - eccentricitySquared)) / (magic * sqrtMagic) * .pi)
        let longitudeOffset = (offsets.longitude * 180.0)
            / (semiMajorAxis / sqrtMagic * cos(radians) * .pi)

        return CLLocationCoordinate2D(
            latitude: latitude + latitudeOffset,
            longitude: longitude + longitudeOffset
        )
    }

    /// Inverse by fixed-point iteration: GCJ-02 has no closed-form inverse.
    static func gcj02ToWGS84(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        guard isInsideChina(latitude: latitude, longitude: longitude) else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var candidateLatitude = latitude
        var candidateLongitude = longitude
        for _ in 0..<30 {
            let forward = wgs84ToGCJ02(latitude: candidateLatitude, longitude: candidateLongitude)
            let latitudeDelta = forward.latitude - latitude
            let longitudeDelta = forward.longitude - longitude
            if abs(latitudeDelta) < 1e-9, abs(longitudeDelta) < 1e-9 { break }
            candidateLatitude -= latitudeDelta
            candidateLongitude -= longitudeDelta
        }

        return CLLocationCoordinate2D(latitude: candidateLatitude, longitude: candidateLongitude)
    }

    private static func offset(x: Double, y: Double) -> (latitude: Double, longitude: Double) {
        var latitudeOffset = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        latitudeOffset += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        latitudeOffset += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        latitudeOffset += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0

        var longitudeOffset = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        longitudeOffset += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        longitudeOffset += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        longitudeOffset += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0

        return (latitudeOffset, longitudeOffset)
    }
}
