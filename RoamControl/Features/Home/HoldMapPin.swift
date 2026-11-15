import Foundation

/// The marker a held run shows at the point it stopped. The map deliberately hides both the route
/// polyline and the running marker while a run is held, so `HoldMapPin` is the one place that
/// decides whether that point gets a pin of its own and what it is called.
enum HoldMapPin {
    struct Pin: Equatable {
        let name: String
        let coordinate: GeoCoordinate
    }

    static func pin(
        isHolding: Bool,
        coordinate: GeoCoordinate?,
        name: String?
    ) -> Pin? {
        guard isHolding, let coordinate else { return nil }
        return Pin(
            name: HeldPointLabel.title(
                resolvedName: name,
                fallback: String(localized: "Held here")
            ),
            coordinate: coordinate
        )
    }
}
