import XCTest
@testable import RoamControl

final class HumanizedMotionModelTests: XCTestCase {
    private let ground = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)
    private let profile = RunProfile.running
    private let sampleTimes: [TimeInterval] = [0, 0.25, 1, 7.25, 61, 600, 3_600, 86_400]

    // MARK: - Profile

    func testProfileRoundTripsThroughCodable() throws {
        let running = RunProfile.running
        XCTAssertEqual(running.targetSpeedMetersPerSecond, 2.8)
        XCTAssertEqual(running.targetCadenceStepsPerMinute, 170)
        XCTAssertEqual(running.speedVariationFraction, 0.06)
        XCTAssertEqual(running.cadenceVariationFraction, 0.04)
        XCTAssertEqual(running.gpsJitterRadiusMeters, 1.5)
        XCTAssertEqual(running.noiseSeed, 0x524F414D)
        XCTAssertNoThrow(try running.validate())

        let data = try JSONEncoder().encode(running)
        let decoded = try JSONDecoder().decode(RunProfile.self, from: data)
        XCTAssertEqual(decoded, running)

        let custom = RunProfile(
            targetSpeedMetersPerSecond: 3.4,
            targetCadenceStepsPerMinute: 182,
            speedVariationFraction: 0.12,
            cadenceVariationFraction: 0.02,
            gpsJitterRadiusMeters: 2.5,
            noiseSeed: 42
        )
        let customData = try JSONEncoder().encode(custom)
        XCTAssertEqual(try JSONDecoder().decode(RunProfile.self, from: customData), custom)
    }

    func testProfileRejectsOutOfRangeValues() {
        let invalidSpeeds: [Double] = [-0.1, 0.49, 10.01, .nan, .infinity, -Double.infinity]
        for value in invalidSpeeds {
            assertInvalid(makeProfile(speed: value), .invalidSpeed)
        }
        let invalidCadences: [Double] = [59.9, 240.1, -60, .nan, .infinity, -Double.infinity]
        for value in invalidCadences {
            assertInvalid(makeProfile(cadence: value), .invalidCadence)
        }
        let invalidVariations: [Double] = [-0.01, 0.36, 1, .nan, .infinity, -Double.infinity]
        for value in invalidVariations {
            assertInvalid(makeProfile(speedVariation: value), .invalidVariation)
            assertInvalid(makeProfile(cadenceVariation: value), .invalidVariation)
        }
        let invalidJitters: [Double] = [-0.01, 10.01, 50, .nan, .infinity, -Double.infinity]
        for value in invalidJitters {
            assertInvalid(makeProfile(jitter: value), .invalidJitter)
        }

        // Boundary values themselves are valid.
        for value in [0.5, 10.0] {
            XCTAssertNoThrow(try makeProfile(speed: value).validate(), "speed \(value)")
        }
        for value in [60.0, 240.0] {
            XCTAssertNoThrow(try makeProfile(cadence: value).validate(), "cadence \(value)")
        }
        for value in [0.0, 0.35] {
            XCTAssertNoThrow(
                try makeProfile(speedVariation: value, cadenceVariation: value).validate(),
                "variation \(value)"
            )
        }
        for value in [0.0, 10.0] {
            XCTAssertNoThrow(try makeProfile(jitter: value).validate(), "jitter \(value)")
        }
    }

    // MARK: - Determinism

    func testSameSeedProducesSameSamples() {
        let first = HumanizedMotionModel(seed: profile.noiseSeed)
        let second = HumanizedMotionModel(seed: profile.noiseSeed)

        for elapsed in sampleTimes {
            XCTAssertEqual(
                first.speedMetersPerSecond(at: elapsed, profile: profile),
                second.speedMetersPerSecond(at: elapsed, profile: profile),
                "speed at \(elapsed)"
            )
            XCTAssertEqual(
                first.cadenceStepsPerMinute(at: elapsed, profile: profile),
                second.cadenceStepsPerMinute(at: elapsed, profile: profile),
                "cadence at \(elapsed)"
            )
            let coordinate = first.reportedCoordinate(for: ground, at: elapsed, profile: profile)
            XCTAssertEqual(
                coordinate,
                second.reportedCoordinate(for: ground, at: elapsed, profile: profile),
                "coordinate at \(elapsed)"
            )
            XCTAssertEqual(
                coordinate,
                first.reportedCoordinate(for: ground, at: elapsed, profile: profile),
                "repeated call at \(elapsed)"
            )
        }
    }

    func testDifferentSeedsProduceDifferentJitter() {
        let seeds: [UInt64] = [profile.noiseSeed, profile.noiseSeed &+ 1, 1, 0xDEAD_BEEF, 0]
        let models = seeds.map { HumanizedMotionModel(seed: $0) }

        for firstIndex in models.indices {
            for secondIndex in models.indices where secondIndex > firstIndex {
                for elapsed in sampleTimes {
                    let first = models[firstIndex].reportedCoordinate(for: ground, at: elapsed, profile: profile)
                    let second = models[secondIndex].reportedCoordinate(for: ground, at: elapsed, profile: profile)
                    XCTAssertGreaterThan(
                        first.distance(to: second),
                        0.05,
                        "seeds \(seeds[firstIndex]) and \(seeds[secondIndex]) at \(elapsed)"
                    )
                }
            }
        }
    }

    // MARK: - Speed and cadence

    func testSpeedAndCadenceStayWithinConfiguredBounds() {
        let model = HumanizedMotionModel(seed: profile.noiseSeed)
        var elapsedSamples = sampleTimes
        elapsedSamples.append(contentsOf: stride(from: 0.0, through: 600.0, by: 0.37))
        elapsedSamples.append(1_234.567)
        elapsedSamples.append(86_400.125)

        assertBounds(model: model, profile: profile, at: elapsedSamples)

        var wide = profile
        wide.speedVariationFraction = 0.35
        wide.cadenceVariationFraction = 0.35
        XCTAssertNoThrow(try wide.validate())
        assertBounds(model: model, profile: wide, at: elapsedSamples)

        var steady = profile
        steady.speedVariationFraction = 0
        steady.cadenceVariationFraction = 0
        for elapsed in sampleTimes {
            XCTAssertEqual(model.speedMetersPerSecond(at: elapsed, profile: steady), steady.targetSpeedMetersPerSecond)
            XCTAssertEqual(model.cadenceStepsPerMinute(at: elapsed, profile: steady), steady.targetCadenceStepsPerMinute)
        }
    }

    // MARK: - Jitter

    func testZeroJitterReturnsExactGroundCoordinate() {
        var noJitter = profile
        noJitter.gpsJitterRadiusMeters = 0
        XCTAssertNoThrow(try noJitter.validate())

        let model = HumanizedMotionModel(seed: noJitter.noiseSeed)
        for elapsed in sampleTimes {
            let reported = model.reportedCoordinate(for: ground, at: elapsed, profile: noJitter)
            XCTAssertEqual(reported.latitude, ground.latitude, "latitude at \(elapsed)")
            XCTAssertEqual(reported.longitude, ground.longitude, "longitude at \(elapsed)")
            XCTAssertEqual(reported, ground, "coordinate at \(elapsed)")
        }
    }

    func testJitterNeverExceedsRadius() {
        let model = HumanizedMotionModel(seed: profile.noiseSeed)
        let tolerance = 1e-6

        for radius in [0.5, 1.5, 10.0] {
            var jittering = profile
            jittering.gpsJitterRadiusMeters = radius
            XCTAssertNoThrow(try jittering.validate())

            var largestDistance = 0.0
            var elapsed = 0.0
            while elapsed <= 600 {
                let reported = model.reportedCoordinate(for: ground, at: elapsed, profile: jittering)
                XCTAssertTrue(reported.isValid, "radius \(radius) at \(elapsed)")
                let distance = ground.distance(to: reported)
                XCTAssertLessThanOrEqual(distance, radius + tolerance, "radius \(radius) at \(elapsed)")
                largestDistance = max(largestDistance, distance)
                elapsed += 0.37
            }

            XCTAssertGreaterThan(largestDistance, radius * 0.2, "radius \(radius) never produced a meaningful offset")
        }
    }

    func testJitterRemainsSmoothBetweenOneSecondSamples() {
        let model = HumanizedMotionModel(seed: profile.noiseSeed)
        let radius = profile.gpsJitterRadiusMeters
        let sampleCount = 12

        // Two independently drawn points in a disk of radius r sit `128r / (45π)` apart on
        // average, so a one-second step must stay far below that to count as smooth.
        let independentMeanDistance = 128.0 * radius / (45.0 * Double.pi)
        let maximumAllowedStep = 0.3 * independentMeanDistance

        for start in [0.0, 1.5, 3.7, 100.25] {
            var previous = model.reportedCoordinate(for: ground, at: start, profile: profile)
            var steps: [Double] = []
            for index in 1...sampleCount {
                let elapsed = start + Double(index)
                let current = model.reportedCoordinate(for: ground, at: elapsed, profile: profile)
                steps.append(previous.distance(to: current))
                previous = current
            }

            let largestStep = steps.max() ?? 0
            XCTAssertGreaterThan(largestStep, 0, "jitter never moved from \(start)")
            XCTAssertLessThanOrEqual(
                largestStep,
                maximumAllowedStep,
                "one-second jitter step \(largestStep) m from \(start) exceeds \(maximumAllowedStep) m"
            )
        }

        let firstCoordinate = model.reportedCoordinate(for: ground, at: 0, profile: profile)
        let lastCoordinate = model.reportedCoordinate(for: ground, at: Double(sampleCount), profile: profile)
        XCTAssertGreaterThan(
            firstCoordinate.distance(to: lastCoordinate),
            0.02 * radius,
            "jitter stayed still across \(sampleCount) seconds"
        )
    }

    // MARK: - Helpers

    private func makeProfile(
        speed: Double? = nil,
        cadence: Double? = nil,
        speedVariation: Double? = nil,
        cadenceVariation: Double? = nil,
        jitter: Double? = nil
    ) -> RunProfile {
        let base = RunProfile.running
        return RunProfile(
            targetSpeedMetersPerSecond: speed ?? base.targetSpeedMetersPerSecond,
            targetCadenceStepsPerMinute: cadence ?? base.targetCadenceStepsPerMinute,
            speedVariationFraction: speedVariation ?? base.speedVariationFraction,
            cadenceVariationFraction: cadenceVariation ?? base.cadenceVariationFraction,
            gpsJitterRadiusMeters: jitter ?? base.gpsJitterRadiusMeters,
            noiseSeed: base.noiseSeed
        )
    }

    private func assertInvalid(
        _ profile: RunProfile,
        _ expected: RunProfileValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try profile.validate(), file: file, line: line) { error in
            XCTAssertEqual(error as? RunProfileValidationError, expected, file: file, line: line)
        }
    }

    private func assertBounds(
        model: HumanizedMotionModel,
        profile: RunProfile,
        at elapsedSamples: [TimeInterval],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let speedLower = profile.targetSpeedMetersPerSecond * (1 - profile.speedVariationFraction)
        let speedUpper = profile.targetSpeedMetersPerSecond * (1 + profile.speedVariationFraction)
        let cadenceLower = profile.targetCadenceStepsPerMinute * (1 - profile.cadenceVariationFraction)
        let cadenceUpper = profile.targetCadenceStepsPerMinute * (1 + profile.cadenceVariationFraction)

        for elapsed in elapsedSamples {
            let speed = model.speedMetersPerSecond(at: elapsed, profile: profile)
            XCTAssertGreaterThanOrEqual(speed, speedLower, "speed at \(elapsed)", file: file, line: line)
            XCTAssertLessThanOrEqual(speed, speedUpper, "speed at \(elapsed)", file: file, line: line)

            let cadence = model.cadenceStepsPerMinute(at: elapsed, profile: profile)
            XCTAssertGreaterThanOrEqual(cadence, cadenceLower, "cadence at \(elapsed)", file: file, line: line)
            XCTAssertLessThanOrEqual(cadence, cadenceUpper, "cadence at \(elapsed)", file: file, line: line)
        }
    }
}
