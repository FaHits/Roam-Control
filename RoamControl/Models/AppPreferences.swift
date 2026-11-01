import Foundation
import MapKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Auto")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

enum MapDisplayStyle: String, CaseIterable, Identifiable {
    case standard
    case satellite
    case hybrid

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .satellite: String(localized: "Satellite")
        case .hybrid: String(localized: "Hybrid")
        }
    }

    /// Single source for the MapKit style; `HomeView` and the route editor both read this.
    var mapStyle: MapStyle {
        switch self {
        case .standard: .standard(elevation: .realistic)
        case .satellite: .imagery(elevation: .realistic)
        case .hybrid: .hybrid(elevation: .realistic)
        }
    }
}
