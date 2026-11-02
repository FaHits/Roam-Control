import XCTest
@testable import RoamControl

final class HumanizedMotionModelTests: XCTestCase {
    private let ground = GeoCoordinate(latitude: 31.2304, longitude: 121.4737)
    private let profile = RunProfile.running
    private let sampleTimes: [TimeInterval] = [0, 0.25, 1, 7.25, 61, 600, 3_600, 86_400]

    /// Roughly 414 m square loop, the same one `RouteRunnerTests` drives.
    private var square: [GeoCoordinate] {
        [
            ground,
            GeoCoordinate(latitude: 31.2304, longitude: 121.4747),
            GeoCoordinate(latitude: 31.2314, longitude: 121.4747),
            GeoCoordinate(latitude: 31.2314, longitude: 121.4737)
        ]
    }

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
                first.speedMetersPerSecond(at: elapsed, profile: profile, remainingDistance: nil),
                second.speedMetersPerSecond(at: elapsed, profile: profile, remainingDistance: nil),
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

        assertBounds(model: model, profile: profile, at: elapsedSamples, remainingDistance: nil)

        var wide = profile
        wide.speedVariationFraction = 0.35
        wide.cadenceVariationFraction = 0.35
        XCTAssertNoThrow(try wide.validate())
        assertBounds(model: model, profile: wide, at: elapsedSamples, remainingDistance: nil)
        assertBounds(model: model, profile: wide, at: elapsedSamples, remainingDistance: 40)

        // With every factor switched off the speed is exactly the target again.
        var steady = profile
        steady.speedVariationFraction = 0
        steady.cadenceVariationFraction = 0
        steady.rampDuration = 0
        steady.fatiguePerMinute = 0
        steady.cooldownDistance = 0
        XCTAssertNoThrow(try steady.validate())
        for elapsed in sampleTimes {
            XCTAssertEqual(
                model.speedMetersPerSecond(at: elapsed, profile: steady, remainingDistance: 0),
                steady.targetSpeedMetersPerSecond
            )
            XCTAssertEqual(
                model.cadenceStepsPerMinute(at: elapsed, profile: steady),
                steady.targetCadenceStepsPerMinute
            )
        }
    }

    // MARK: - Ramp-up

    func testRampStartsAtThirtyPercentAndReachesTarget() {
        let ramping = makeProfile(ramp: 20)

        XCTAssertEqual(HumanizedMotionModel.rampFactor(at: 0, profile: ramping), 0.3, accuracy: 1e-12)
        XCTAssertEqual(HumanizedMotionModel.rampFactor(at: 10, profile: ramping), 0.65, accuracy: 1e-12)
        XCTAssertEqual(HumanizedMotionModel.rampFactor(at: 20, profile: ramping), 1.0, accuracy: 1e-12)
        XCTAssertEqual(HumanizedMotionModel.rampFactor(at: 600, profile: ramping), 1.0, accuracy: 1e-12)
        // Before the start the ramp is clamped, never extrapolated below 30%.
        XCTAssertEqual(HumanizedMotionModel.rampFactor(at: -5, profile: ramping), 0.3, accuracy: 1e-12)

        let noRamp = makeProfile(ramp: 0)
        for elapsed in sampleTimes {
            XCTAssertEqual(HumanizedMotionModel.rampFactor(at: elapsed, profile: noRamp), 1.0, accuracy: 1e-12)
        }

        // The speed itself starts at 30% of the target and is back at it once the ramp is over.
        var exact = makeProfile(ramp: 20, fatigue: 0, cooldown: 0)
        exact.speedVariationFraction = 0
        let model = HumanizedMotionModel(seed: exact.noiseSeed)
        XCTAssertEqual(
            model.speedMetersPerSecond(at: 0, profile: exact, remainingDistance: nil),
            exact.targetSpeedMetersPerSecond * 0.3,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            model.speedMetersPerSecond(at: 20, profile: exact, remainingDistance: nil),
            exact.targetSpeedMetersPerSecond,
            accuracy: 1e-12
        )
    }

    func testRampIsMonotonicNonDecreasing() {
        let ramping = makeProfile(ramp: 20)
        var previous = HumanizedMotionModel.rampFactor(at: -10, profile: ramping)
        var elapsed = -10.0
        while elapsed <= 70 {
            let current = HumanizedMotionModel.rampFactor(at: elapsed, profile: ramping)
            XCTAssertGreaterThanOrEqual(current, previous - 1e-12, "ramp dipped at \(elapsed)")
            previous = current
            elapsed += 0.1
        }

        XCTAssertEqual(HumanizedMotionModel.rampFactor(at: 0, profile: ramping), 0.3, accuracy: 1e-12)
        XCTAssertEqual(HumanizedMotionModel.rampFactor(at: 20, profile: ramping), 1.0, accuracy: 1e-12)
    }

    // MARK: - Fatigue

    func testFatigueDropsAboutEighteenPercentOverTenMinutes() {
        let fatiguing = makeProfile(fatigue: 0.018)

        XCTAssertEqual(HumanizedMotionModel.fatigueFactor(at: 0, profile: fatiguing), 1.0, accuracy: 1e-12)
        XCTAssertEqual(HumanizedMotionModel.fatigueFactor(at: 300, profile: fatiguing), 0.91, accuracy: 1e-12)
        XCTAssertEqual(HumanizedMotionModel.fatigueFactor(at: 600, profile: fatiguing), 0.82, accuracy: 1e-12)

        var exact = makeProfile(ramp: 0, fatigue: 0.018, cooldown: 0)
        exact.speedVariationFraction = 0
        let model = HumanizedMotionModel(seed: exact.noiseSeed)
        let start = model.speedMetersPerSecond(at: 0, profile: exact, remainingDistance: nil)
        let tenMinutes = model.speedMetersPerSecond(at: 600, profile: exact, remainingDistance: nil)
        XCTAssertEqual(tenMinutes / start, 0.82, accuracy: 1e-12)
    }

    func testFatigueNeverFallsBelowMinSpeedFraction() {
        let fatiguing = makeProfile(fatigue: 0.05)
        XCTAssertEqual(fatiguing.minSpeedFraction, 0.6, accuracy: 1e-12)

        for elapsed in [0.0, 300, 600, 3_600, 86_400] {
            let factor = HumanizedMotionModel.fatigueFactor(at: elapsed, profile: fatiguing)
            XCTAssertGreaterThanOrEqual(factor, 0.6 - 1e-12, "fatigue factor \(factor) at \(elapsed)")
        }
        XCTAssertEqual(
            HumanizedMotionModel.fatigueFactor(at: 86_400, profile: fatiguing),
            0.6,
            accuracy: 1e-12
        )

        var slowFloor = fatiguing
        slowFloor.minSpeedFraction = 0.9
        XCTAssertNoThrow(try slowFloor.validate())
        XCTAssertEqual(HumanizedMotionModel.fatigueFactor(at: 600, profile: slowFloor), 0.9, accuracy: 1e-12)

        var exact = makeProfile(ramp: 0, fatigue: 0.05, cooldown: 0)
        exact.speedVariationFraction = 0
        let model = HumanizedMotionModel(seed: exact.noiseSeed)
        XCTAssertEqual(
            model.speedMetersPerSecond(at: 86_400, profile: exact, remainingDistance: nil),
            exact.targetSpeedMetersPerSecond * exact.minSpeedFraction,
            accuracy: 1e-12
        )
    }

    // MARK: - Cool-down

    func testCooldownOnlyAppliesInsideTheFinalMetres() {
        let cooling = makeProfile()

        XCTAssertEqual(
            HumanizedMotionModel.cooldownFactor(remainingDistance: nil, profile: cooling),
            1.0,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            HumanizedMotionModel.cooldownFactor(remainingDistance: 500, profile: cooling),
            1.0,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            HumanizedMotionModel.cooldownFactor(remainingDistance: 120, profile: cooling),
            1.0,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            HumanizedMotionModel.cooldownFactor(remainingDistance: 60, profile: cooling),
            0.675,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            HumanizedMotionModel.cooldownFactor(remainingDistance: 0, profile: cooling),
            0.35,
            accuracy: 1e-12
        )
        // Running past the finish clamps instead of extrapolating below 35%.
        XCTAssertEqual(
            HumanizedMotionModel.cooldownFactor(remainingDistance: -10, profile: cooling),
            0.35,
            accuracy: 1e-12
        )

        var previous = HumanizedMotionModel.cooldownFactor(remainingDistance: 0, profile: cooling)
        var remaining = 0.0
        while remaining <= 200 {
            let factor = HumanizedMotionModel.cooldownFactor(remainingDistance: remaining, profile: cooling)
            XCTAssertGreaterThanOrEqual(factor, previous - 1e-12, "cool-down dipped at \(remaining)")
            previous = factor
            remaining += 2
        }

        let noCoolDown = makeProfile(cooldown: 0)
        for distance in [0.0, 10, 60, 500] {
            XCTAssertEqual(
                HumanizedMotionModel.cooldownFactor(remainingDistance: distance, profile: noCoolDown),
                1.0,
                accuracy: 1e-12
            )
        }
    }

    func testContinuousRunNeverCooldowns() throws {
        let geometry = try RouteGeometry(points: square, isClosed: true)
        var continuous = RunProfile.running
        continuous.speedVariationFraction = 0
        continuous.cadenceVariationFraction = 0
        continuous.gpsJitterRadiusMeters = 0
        continuous.rampDuration = 0
        continuous.fatiguePerMinute = 0
        continuous.cooldownDistance = 120
        XCTAssertNoThrow(try continuous.validate())

        var runner = try RouteRunner(geometry: geometry, profile: continuous, mode: .continuous)
        runner.start()

        for _ in 0..<400 {
            let snapshot = runner.advance(by: 1)
            XCTAssertEqual(
                snapshot.speedMetersPerSecond,
                continuous.targetSpeedMetersPerSecond,
                accuracy: 1e-9,
                "a continuous run slowed down at \(snapshot.totalDistance) m"
            )
        }
        // Well past one full lap, so a wrongly applied cool-down would have fired.
        XCTAssertGreaterThan(runner.snapshot.totalDistance, geometry.totalDistance)
    }

    func testSpeedStaysPositiveAndDeterministic() {
        var worst = RunProfile.running
        worst.rampDuration = 60
        worst.fatiguePerMinute = 0.05
        worst.cooldownDistance = 300
        worst.minSpeedFraction = 0.1
        worst.speedVariationFraction = 0.35
        XCTAssertNoThrow(try worst.validate())

        let first = HumanizedMotionModel(seed: worst.noiseSeed)
        let second = HumanizedMotionModel(seed: worst.noiseSeed)
        let remainings: [Double?] = [nil, 0, 0.5, 120, 300, 5_000]

        for elapsed in sampleTimes + [1_234.567, 86_400.125] {
            for remaining in remainings {
                let speed = first.speedMetersPerSecond(
                    at: elapsed,
                    profile: worst,
                    remainingDistance: remaining
                )
                XCTAssertTrue(speed.isFinite, "speed at \(elapsed)/\(String(describing: remaining))")
                XCTAssertGreaterThanOrEqual(
                    speed,
                    0.3,
                    "speed \(speed) at \(elapsed)/\(String(describing: remaining))"
                )
                XCTAssertEqual(
                    speed,
                    second.speedMetersPerSecond(at: elapsed, profile: worst, remainingDistance: remaining)
                )
                XCTAssertEqual(
                    speed,
                    first.speedMetersPerSecond(at: elapsed, profile: worst, remainingDistance: remaining)
                )
            }
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
        jitter: Double? = nil,
        ramp: TimeInterval? = nil,
        fatigue: Double? = nil,
        cooldown: Double? = nil
    ) -> RunProfile {
        let base = RunProfile.running
        return RunProfile(
            targetSpeedMetersPerSecond: speed ?? base.targetSpeedMetersPerSecond,
            targetCadenceStepsPerMinute: cadence ?? base.targetCadenceStepsPerMinute,
            speedVariationFraction: speedVariation ?? base.speedVariationFraction,
            cadenceVariationFraction: cadenceVariation ?? base.cadenceVariationFraction,
            gpsJitterRadiusMeters: jitter ?? base.gpsJitterRadiusMeters,
            noiseSeed: base.noiseSeed,
            rampDuration: ramp ?? base.rampDuration,
            fatiguePerMinute: fatigue ?? base.fatiguePerMinute,
            cooldownDistance: cooldown ?? base.cooldownDistance
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

    /// The wobble stays inside `target * (1 ± variation)`, and the three run-shape factors scale
    /// that band instead of adding to it.
    private func assertBounds(
        model: HumanizedMotionModel,
        profile: RunProfile,
        at elapsedSamples: [TimeInterval],
        remainingDistance: Double?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let cadenceLower = profile.targetCadenceStepsPerMinute * (1 - profile.cadenceVariationFraction)
        let cadenceUpper = profile.targetCadenceStepsPerMinute * (1 + profile.cadenceVariationFraction)

        for elapsed in elapsedSamples {
            let envelope = HumanizedMotionModel.rampFactor(at: elapsed, profile: profile)
                * HumanizedMotionModel.fatigueFactor(at: elapsed, profile: profile)
                * HumanizedMotionModel.cooldownFactor(remainingDistance: remainingDistance, profile: profile)
            let speedLower = profile.targetSpeedMetersPerSecond * (1 - profile.speedVariationFraction) * envelope
            let speedUpper = profile.targetSpeedMetersPerSecond * (1 + profile.speedVariationFraction) * envelope
            let speed = model.speedMetersPerSecond(
                at: elapsed,
                profile: profile,
                remainingDistance: remainingDistance
            )
            XCTAssertLessThanOrEqual(speed, speedUpper, "speed at \(elapsed)", file: file, line: line)
            // The floor only lifts speeds the factors would otherwise crush.
            if speedLower >= 0.3 {
                XCTAssertGreaterThanOrEqual(speed, speedLower, "speed at \(elapsed)", file: file, line: line)
            }

            let cadence = model.cadenceStepsPerMinute(at: elapsed, profile: profile)
            XCTAssertGreaterThanOrEqual(cadence, cadenceLower, "cadence at \(elapsed)", file: file, line: line)
            XCTAssertLessThanOrEqual(cadence, cadenceUpper, "cadence at \(elapsed)", file: file, line: line)
        }
    }
}
