import CoreLocation
import MapKit

/// One reverse-geocode lookup for a held point's label. Any failure is `nil`, so the caller falls
/// back to "Held here": a held run must never fail, block or stay unnamed because the lookup did.
enum HeldPointNameResolver {
    static func name(for coordinate: GeoCoordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        guard let items = try? await request.mapItems, let item = items.first else { return nil }
        guard
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        else {
            return nil
        }
        return name
    }
}
