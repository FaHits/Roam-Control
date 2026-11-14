import Foundation

/// The one target a held run shows everywhere: the point the iPhone is really holding, named after
/// the place, with no route subtitle. `ConnectionHealthView` hides its Area row when the subtitle is
/// empty, which is what removes laps, speed and cadence from a held run.
enum HeldPointTarget {
    static func make(coordinate: GeoCoordinate, resolvedName: String?) -> LocationTarget {
        LocationTarget(
            name: HeldPointLabel.title(
                resolvedName: resolvedName,
                fallback: String(localized: "Held here")
            ),
            subtitle: "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
