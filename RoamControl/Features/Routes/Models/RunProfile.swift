import Foundation

enum RunProfileValidationError: Error, Equatable, Sendable {
    case invalidSpeed
    case invalidCadence
    case invalidVariation
    case invalidJitter
}

/// Motion settings for a simulated run: the ground speed the runner advances at, the cadence
/// shown in the UI, how far either signal may wander, and how much the reported GPS coordinate
/// may drift around the ground coordinate.
struct RunProfile: Codable, Equatable, Sendable {
    static let speedRange: ClosedRange<Double> = 0.5...10.0
    static let cadenceRange: ClosedRange<Double> = 60.0...240.0
    static let variationRange: ClosedRange<Double> = 0.0...0.35
    static let jitterRadiusRange: ClosedRange<Double> = 0.0...10.0

    var targetSpeedMetersPerSecond: Double
    var targetCadenceStepsPerMinute: Double
    var speedVariationFraction: Double
    var cadenceVariationFraction: Double
    var gpsJitterRadiusMeters: Double
    var noiseSeed: UInt64

    static let running = RunProfile(
        targetSpeedMetersPerSecond: 2.8,
        targetCadenceStepsPerMinute: 170,
        speedVariationFraction: 0.06,
        cadenceVariationFraction: 0.04,
        gpsJitterRadiusMeters: 1.5,
        noiseSeed: 0x524F_414D
    )

    /// `ClosedRange.contains` already rejects NaN and both infinities, so non-finite values
    /// surface as the same errors as out-of-range ones.
    func validate() throws {
        guard Self.speedRange.contains(targetSpeedMetersPerSecond) else {
            throw RunProfileValidationError.invalidSpeed
        }
        guard Self.cadenceRange.contains(targetCadenceStepsPerMinute) else {
            throw RunProfileValidationError.invalidCadence
        }
        guard Self.variationRange.contains(speedVariationFraction),
              Self.variationRange.contains(cadenceVariationFraction) else {
            throw RunProfileValidationError.invalidVariation
        }
        guard Self.jitterRadiusRange.contains(gpsJitterRadiusMeters) else {
            throw RunProfileValidationError.invalidJitter
        }
    }
}
