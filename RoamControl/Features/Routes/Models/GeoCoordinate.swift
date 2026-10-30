import CoreLocation
import Foundation

struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90.0...90.0).contains(latitude)
            && (-180.0...180.0).contains(longitude)
    }

    func distance(to other: GeoCoordinate) -> Double {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(
            latitude: other.latitude,
            longitude: other.longitude
        )
        return location.distance(from: otherLocation)
    }
}
