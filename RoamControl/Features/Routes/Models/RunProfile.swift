import Foundation

enum RunProfileValidationError: Error, Equatable, Sendable {
    case invalidSpeed
    case invalidCadence
    case invalidVariation
    case invalidJitter
    case invalidRampDuration
    case invalidFatigue
    case invalidCooldownDistance
    case invalidMinSpeedFraction
}

/// Motion settings for a simulated run: the ground speed the runner advances at, the cadence
/// shown in the UI, how far either signal may wander, how much the reported GPS coordinate may
/// drift around the ground coordinate, and the three shape factors that make the pace change over
/// the run (ramp-up, fatigue, cool-down).
struct RunProfile: Codable, Equatable, Sendable {
    static let speedRange: ClosedRange<Double> = 0.5...10.0
    static let cadenceRange: ClosedRange<Double> = 60.0...240.0
    static let variationRange: ClosedRange<Double> = 0.0...0.35
    static let jitterRadiusRange: ClosedRange<Double> = 0.0...10.0
    static let rampDurationRange: ClosedRange<TimeInterval> = 0.0...60.0
    static let fatiguePerMinuteRange: ClosedRange<Double> = 0.0...0.05
    static let cooldownDistanceRange: ClosedRange<Double> = 0.0...300.0
    static let minSpeedFractionRange: ClosedRange<Double> = 0.1...1.0

    static let defaultRampDuration: TimeInterval = 20
    static let defaultFatiguePerMinute = 0.018
    static let defaultCooldownDistance = 120.0
    static let defaultMinSpeedFraction = 0.6

    var targetSpeedMetersPerSecond: Double
    var targetCadenceStepsPerMinute: Double
    var speedVariationFraction: Double
    var cadenceVariationFraction: Double
    var gpsJitterRadiusMeters: Double
    var noiseSeed: UInt64

    /// Seconds spent ramping from 30% of the target speed to 100%.
    var rampDuration: TimeInterval = RunProfile.defaultRampDuration
    /// Share of the target speed lost per minute of running.
    var fatiguePerMinute: Double = RunProfile.defaultFatiguePerMinute
    /// Metres before the finish where the cool-down starts pulling the speed down.
    var cooldownDistance: Double = RunProfile.defaultCooldownDistance
    /// Floor fatigue may never cross. Not user facing: no settings slider writes it.
    var minSpeedFraction: Double = RunProfile.defaultMinSpeedFraction

    static let running = RunProfile(
        targetSpeedMetersPerSecond: 2.8,
        targetCadenceStepsPerMinute: 170,
        speedVariationFraction: 0.06,
        cadenceVariationFraction: 0.04,
        gpsJitterRadiusMeters: 1.5,
        noiseSeed: 0x524F_414D
    )

    enum CodingKeys: String, CodingKey {
        case targetSpeedMetersPerSecond
        case targetCadenceStepsPerMinute
        case speedVariationFraction
        case cadenceVariationFraction
        case gpsJitterRadiusMeters
        case noiseSeed
        case rampDuration
        case fatiguePerMinute
        case cooldownDistance
        case minSpeedFraction
    }

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
        guard Self.rampDurationRange.contains(rampDuration) else {
            throw RunProfileValidationError.invalidRampDuration
        }
        guard Self.fatiguePerMinuteRange.contains(fatiguePerMinute) else {
            throw RunProfileValidationError.invalidFatigue
        }
        guard Self.cooldownDistanceRange.contains(cooldownDistance) else {
            throw RunProfileValidationError.invalidCooldownDistance
        }
        guard Self.minSpeedFractionRange.contains(minSpeedFraction) else {
            throw RunProfileValidationError.invalidMinSpeedFraction
        }
    }
}

extension RunProfile {
    /// A profile written by a build without the motion fields has none of their keys, so each one
    /// falls back to its default instead of failing the whole record.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetSpeedMetersPerSecond = try container.decode(
            Double.self,
            forKey: .targetSpeedMetersPerSecond
        )
        targetCadenceStepsPerMinute = try container.decode(
            Double.self,
            forKey: .targetCadenceStepsPerMinute
        )
        speedVariationFraction = try container.decode(
            Double.self,
            forKey: .speedVariationFraction
        )
        cadenceVariationFraction = try container.decode(
            Double.self,
            forKey: .cadenceVariationFraction
        )
        gpsJitterRadiusMeters = try container.decode(Double.self, forKey: .gpsJitterRadiusMeters)
        noiseSeed = try container.decode(UInt64.self, forKey: .noiseSeed)
        rampDuration = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .rampDuration
        ) ?? Self.defaultRampDuration
        fatiguePerMinute = try container.decodeIfPresent(
            Double.self,
            forKey: .fatiguePerMinute
        ) ?? Self.defaultFatiguePerMinute
        cooldownDistance = try container.decodeIfPresent(
            Double.self,
            forKey: .cooldownDistance
        ) ?? Self.defaultCooldownDistance
        minSpeedFraction = try container.decodeIfPresent(
            Double.self,
            forKey: .minSpeedFraction
        ) ?? Self.defaultMinSpeedFraction
    }
}
