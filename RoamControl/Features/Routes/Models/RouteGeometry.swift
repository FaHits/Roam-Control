import Foundation

enum RouteGeometryError: Error, Equatable, Sendable {
    case invalidCoordinate
    case tooFewPoints(minimum: Int)
    case zeroLength
}

struct RouteGeometry: Equatable, Sendable {
    static let duplicateDistanceThreshold = 0.5

    let points: [GeoCoordinate]
    let isClosed: Bool
    let segmentLengths: [Double]
    let totalDistance: Double

    init(points: [GeoCoordinate], isClosed: Bool) throws {
        guard points.allSatisfy(\.isValid) else {
            throw RouteGeometryError.invalidCoordinate
        }

        var effectivePoints = points.reduce(into: [GeoCoordinate]()) { result, point in
            guard let previous = result.last else {
                result.append(point)
                return
            }
            if previous.distance(to: point) >= Self.duplicateDistanceThreshold {
                result.append(point)
            }
        }

        if isClosed, effectivePoints.count > 1,
           effectivePoints.last!.distance(to: effectivePoints.first!) < Self.duplicateDistanceThreshold {
            effectivePoints.removeLast()
        }

        let minimum = isClosed ? 3 : 2
        if effectivePoints.count < minimum {
            if isClosed, effectivePoints.count == 1 {
                throw RouteGeometryError.zeroLength
            }
            throw RouteGeometryError.tooFewPoints(minimum: minimum)
        }

        let geometryPoints = isClosed ? effectivePoints + [effectivePoints[0]] : effectivePoints
        let lengths = zip(geometryPoints, geometryPoints.dropFirst()).map { start, end in
            start.distance(to: end)
        }
        let total = lengths.reduce(0, +)
        guard total > 0 else {
            throw RouteGeometryError.zeroLength
        }

        self.points = geometryPoints
        self.isClosed = isClosed
        self.segmentLengths = lengths
        self.totalDistance = total
    }

    func coordinate(atDistance distance: Double) -> GeoCoordinate {
        guard let start = points.first, let end = points.last else {
            preconditionFailure("RouteGeometry must contain at least two points")
        }
        guard !distance.isNaN, distance > 0 else {
            return start
        }
        guard distance < totalDistance else {
            return end
        }

        var distanceBeforeSegment = 0.0
        for (index, segmentLength) in segmentLengths.enumerated() {
            let distanceAfterSegment = distanceBeforeSegment + segmentLength
            if distance <= distanceAfterSegment {
                let segmentProgress = (distance - distanceBeforeSegment) / segmentLength
                let segmentStart = points[index]
                let segmentEnd = points[index + 1]
                return GeoCoordinate(
                    latitude: segmentStart.latitude
                        + (segmentEnd.latitude - segmentStart.latitude) * segmentProgress,
                    longitude: segmentStart.longitude
                        + (segmentEnd.longitude - segmentStart.longitude) * segmentProgress
                )
            }
            distanceBeforeSegment = distanceAfterSegment
        }

        return end
    }
}
