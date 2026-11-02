import XCTest
@testable import RoamControl

final class RunProfileTests: XCTestCase {
    /// Exactly what a build before the motion fields wrote: six keys, none of the new ones.
    private let legacyProfileJSON = """
    {
      "targetSpeedMetersPerSecond" : 3.1,
      "targetCadenceStepsPerMinute" : 175,
      "speedVariationFraction" : 0.08,
      "cadenceVariationFraction" : 0.03,
      "gpsJitterRadiusMeters" : 2,
      "noiseSeed" : 42
    }
    """

    func testNewMotionFieldsDefaultWhenDecodingAnOlderProfile() throws {
        let decoded = try JSONDecoder().decode(RunProfile.self, from: Data(legacyProfileJSON.utf8))

        XCTAssertEqual(decoded.targetSpeedMetersPerSecond, 3.1)
        XCTAssertEqual(decoded.targetCadenceStepsPerMinute, 175)
        XCTAssertEqual(decoded.speedVariationFraction, 0.08)
        XCTAssertEqual(decoded.cadenceVariationFraction, 0.03)
        XCTAssertEqual(decoded.gpsJitterRadiusMeters, 2)
        XCTAssertEqual(decoded.noiseSeed, 42)

        XCTAssertEqual(decoded.rampDuration, 20)
        XCTAssertEqual(decoded.fatiguePerMinute, 0.018)
        XCTAssertEqual(decoded.cooldownDistance, 120)
        XCTAssertEqual(decoded.minSpeedFraction, 0.6)
        XCTAssertNoThrow(try decoded.validate())

        // Re-encoding writes the new keys, so a later decode keeps the values instead of
        // falling back again.
        let reencoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try JSONDecoder().decode(RunProfile.self, from: reencoded), decoded)
    }

    func testMotionFieldRangesAreValidated() {
        for value in [-0.1, 60.1, 120, .nan, .infinity, -Double.infinity] {
            assertInvalid(makeProfile(ramp: value), .invalidRampDuration, "ramp \(value)")
        }
        for value in [-0.001, 0.051, 1, .nan, .infinity, -Double.infinity] {
            assertInvalid(makeProfile(fatigue: value), .invalidFatigue, "fatigue \(value)")
        }
        for value in [-0.1, 300.1, 1_000, .nan, .infinity, -Double.infinity] {
            assertInvalid(makeProfile(cooldown: value), .invalidCooldownDistance, "cooldown \(value)")
        }
        for value in [-0.1, 0.09, 1.01, 2, .nan, .infinity, -Double.infinity] {
            assertInvalid(makeProfile(minimum: value), .invalidMinSpeedFraction, "floor \(value)")
        }

        // The range endpoints themselves are valid.
        for value in [0.0, 60.0] {
            XCTAssertNoThrow(try makeProfile(ramp: value).validate(), "ramp \(value)")
        }
        for value in [0.0, 0.05] {
            XCTAssertNoThrow(try makeProfile(fatigue: value).validate(), "fatigue \(value)")
        }
        for value in [0.0, 300.0] {
            XCTAssertNoThrow(try makeProfile(cooldown: value).validate(), "cooldown \(value)")
        }
        for value in [0.1, 1.0] {
            XCTAssertNoThrow(try makeProfile(minimum: value).validate(), "floor \(value)")
        }
    }

    // MARK: - Helpers

    private func makeProfile(
        ramp: TimeInterval? = nil,
        fatigue: Double? = nil,
        cooldown: Double? = nil,
        minimum: Double? = nil
    ) -> RunProfile {
        let base = RunProfile.running
        return RunProfile(
            targetSpeedMetersPerSecond: base.targetSpeedMetersPerSecond,
            targetCadenceStepsPerMinute: base.targetCadenceStepsPerMinute,
            speedVariationFraction: base.speedVariationFraction,
            cadenceVariationFraction: base.cadenceVariationFraction,
            gpsJitterRadiusMeters: base.gpsJitterRadiusMeters,
            noiseSeed: base.noiseSeed,
            rampDuration: ramp ?? base.rampDuration,
            fatiguePerMinute: fatigue ?? base.fatiguePerMinute,
            cooldownDistance: cooldown ?? base.cooldownDistance,
            minSpeedFraction: minimum ?? base.minSpeedFraction
        )
    }

    private func assertInvalid(
        _ profile: RunProfile,
        _ expected: RunProfileValidationError,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try profile.validate(), label, file: file, line: line) { error in
            XCTAssertEqual(error as? RunProfileValidationError, expected, label, file: file, line: line)
        }
    }
}
