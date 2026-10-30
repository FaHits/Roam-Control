import Foundation

enum RouteSource: String, Codable, Equatable, Hashable, Sendable {
    case drawn
    case gpx
    case appleMaps
}

struct RouteDefinition: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var points: [GeoCoordinate]
    var isClosed: Bool
    var source: RouteSource
    let createdAt: Date
    var updatedAt: Date
}
