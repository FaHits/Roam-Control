import Foundation

/// Deterministic humanized motion.
///
/// Speed and cadence wobble around the configured target with a smooth, low-frequency drift, and the
/// reported GPS coordinate is offset by a bounded two-dimensional jitter. Every output is a
/// pure function of the seed, the elapsed time, the profile and the ground coordinate: the
/// same inputs always produce the same numbers, and no random source is touched per tick.
///
/// The model never moves the ground coordinate and never advances the route; it only turns a
/// ground position into the coordinate that gets reported.
struct HumanizedMotionModel: Sendable {
    /// Weight of each sine component. Weights sum to one, so the combined wave stays in -1...1.
    private static let weights: [Double] = [0.5, 0.3, 0.2]
    private static let speedPeriods: [Double] = [61, 23, 137]
    private static let cadencePeriods: [Double] = [47, 19, 113]
    private static let northJitterPeriods: [Double] = [97, 41, 211]
    private static let eastJitterPeriods: [Double] = [113, 53, 179]

    /// WGS84 maximum metres per degree of latitude. Using the largest value keeps the converted
    /// offset from ever reporting more distance than the configured radius.
    private static let metresPerDegreeLatitude = 111_700.0
    /// Metres per degree of longitude on the equator, the widest parallel.
    private static let metresPerDegreeLongitudeAtEquator = 111_320.0
    private static let degreesPerRadian = 180.0 / Double.pi

    private let speedPhases: [Double]
    private let cadencePhases: [Double]
    private let northJitterPhases: [Double]
    private let eastJitterPhases: [Double]

    /// The seed only fixes the phase of every component; nothing is random per sample.
    init(seed: UInt64) {
        let generated = Self.phases(seed: seed, count: 12)
        speedPhases = Array(generated[0..<3])
        cadencePhases = Array(generated[3..<6])
        northJitterPhases = Array(generated[6..<9])
        eastJitterPhases = Array(generated[9..<12])
    }

    func speedMetersPerSecond(at elapsed: TimeInterval, profile: RunProfile) -> Double {
        let wave = Self.wave(at: elapsed, periods: Self.speedPeriods, phases: speedPhases)
        return profile.targetSpeedMetersPerSecond * (1 + profile.speedVariationFraction * wave)
    }

    func cadenceStepsPerMinute(at elapsed: TimeInterval, profile: RunProfile) -> Double {
        let wave = Self.wave(at: elapsed, periods: Self.cadencePeriods, phases: cadencePhases)
        return profile.targetCadenceStepsPerMinute * (1 + profile.cadenceVariationFraction * wave)
    }

    func reportedCoordinate(
        for groundCoordinate: GeoCoordinate,
        at elapsed: TimeInterval,
        profile: RunProfile
    ) -> GeoCoordinate {
        let radius = profile.gpsJitterRadiusMeters
        guard radius > 0 else { return groundCoordinate }

        // Each axis is capped at radius / √2, so the offset magnitude can never exceed radius
        // and no clamping is needed.
        let axisLimit = radius / 2.0.squareRoot()
        let northOffset = axisLimit * Self.wave(
            at: elapsed,
            periods: Self.northJitterPeriods,
            phases: northJitterPhases
        )
        let eastOffset = axisLimit * Self.wave(
            at: elapsed,
            periods: Self.eastJitterPeriods,
            phases: eastJitterPhases
        )

        let latitudeDelta = northOffset / Self.metresPerDegreeLatitude
        let longitudeWidth = max(cos(groundCoordinate.latitude / Self.degreesPerRadian), 1e-6)
        let longitudeDelta = eastOffset / (Self.metresPerDegreeLongitudeAtEquator * longitudeWidth)

        return GeoCoordinate(
            latitude: min(90, max(-90, groundCoordinate.latitude + latitudeDelta)),
            longitude: min(180, max(-180, groundCoordinate.longitude + longitudeDelta))
        )
    }

    // MARK: - Deterministic noise

    /// Sum of three slow sines, normalized to the weight sum and therefore bounded by -1...1.
    private static func wave(at elapsed: TimeInterval, periods: [Double], phases: [Double]) -> Double {
        let time = elapsed.isFinite ? elapsed : 0
        var sum = 0.0
        for index in periods.indices {
            sum += weights[index] * sin(2 * Double.pi * time / periods[index] + phases[index])
        }
        let bounded = sum / weights.reduce(0.0, +)
        return min(1, max(-1, bounded))
    }

    /// SplitMix64 output mapped to `count` phases in 0..<2π.
    private static func phases(seed: UInt64, count: Int) -> [Double] {
        var state = seed &+ 0x9E37_79B9_7F4A_7C15
        var result: [Double] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            value ^= value >> 31
            result.append(Double(value >> 11) / Double(1 << 53) * 2 * Double.pi)
        }
        return result
    }
}
