# Manual Running Route Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a persistent, manually drawn closed-loop route system to RoamControl so a saved route can be selected after relaunch and run continuously with human-like speed, cadence, and GPS variation.

**Architecture:** A pure Swift route core owns geometry, progress, looping, and deterministic motion. MapKit, SwiftUI, persistence, device sessions, and recovery are adapters around that core. The existing fixed-location and Apple walking flows remain available while the new route system uses its own library, editor, run model, card, and recovery path.

**Tech Stack:** Swift 5, SwiftUI, Observation, MapKit, CoreLocation, Foundation, XCTest, Xcode project at `E:\Ai_Agent\RUN\roam-src`.

---

## Global Constraints

- Source baseline is commit `b68dac0` in `E:\Ai_Agent\RUN\roam-src`; do not change the baseline before the first implementation commit.
- Deployment target remains iOS 27.0; Swift version remains 5.0; app bundle identifier remains `com.sean.roamcontrol`.
- Do not add third-party dependencies.
- `RouteGeometry`, `RouteRunner`, `RunProfile`, and `HumanizedMotionModel` must not import SwiftUI, MapKit, or `AppModel`.
- The only native types allowed in the route core are Foundation and CoreLocation.
- New user-facing text uses the existing English UI language; do not introduce a localization framework in this phase.
- Existing fixed-location behavior must remain unchanged.
- The existing Apple walking flow remains available as a separate route flow in this phase.
- A closed route has at least 3 effective points; an open route has at least 2 effective points.
- Consecutive points closer than 0.5 metres are collapsed for geometry; a route with fewer than the minimum effective points or zero total length is invalid.
- A closed route includes one final segment from the last point back to the first point.
- Route progress uses ground coordinates. GPS jitter changes only the reported coordinate.
- Motion variation is deterministic for a given `RunProfile.noiseSeed`; no per-tick random jumps.
- First version includes continuous speed/cadence variation and bounded jitter only. Start acceleration, fatigue, traffic stops, and run history are out of scope.
- Route files live at `Application Support/RoamControl/routes.json` and are written atomically.
- A recovery snapshot contains its own route definition and does not depend on the current library entry.
- GPX import/export and Apple route conversion into the route library are separate M7 plans; do not add those adapters here.
- Every task ends with focused tests, a build check, and a commit. Do not combine unrelated tasks into one commit.

## Review Focus

- The closed-loop seam must be calculated once in `RouteGeometry`; neither the runner nor the UI may add another closing segment.
- Floating-point handling at exactly one lap, multiple laps in one tick, and long runs must not double-count laps.
- Jitter must never feed back into `distanceInLap`, `completedLaps`, or total distance.
- Existing persisted `SessionRecoveryRecord` JSON must continue to decode after the new optional fields and enum case are added.
- Route deletion must not invalidate an active or interrupted run because recovery carries a route snapshot.
- Home may coordinate screens and commands, but it must not calculate the next route coordinate.
- The existing Apple walking card and controller must keep working until the new route flow has passed its tests.

---

## File Map

New route-core files:

- `RoamControl/Features/Routes/Models/GeoCoordinate.swift`
- `RoamControl/Features/Routes/Models/RouteDefinition.swift`
- `RoamControl/Features/Routes/Models/RouteGeometry.swift`
- `RoamControl/Features/Routes/Models/RunProfile.swift`
- `RoamControl/Features/Routes/Models/RouteRunMode.swift`
- `RoamControl/Features/Routes/Core/HumanizedMotionModel.swift`
- `RoamControl/Features/Routes/Core/RouteRunner.swift`
- `RoamControl/Features/Routes/Storage/RouteStore.swift`
- `RoamControl/Features/Routes/State/RouteLibraryModel.swift`
- `RoamControl/Features/Routes/State/RouteEditorModel.swift`
- `RoamControl/Features/Routes/State/RouteSessionModel.swift`

New route UI files:

- `RoamControl/Features/Routes/Views/RouteEditorView.swift`
- `RoamControl/Features/Routes/Views/RouteLibraryView.swift`
- `RoamControl/Features/Routes/Views/RouteRunSetupView.swift`
- `RoamControl/Features/Routes/Views/RouteRunCard.swift`

New test files:

- `RoamControlTests/BaselineTests.swift`
- `RoamControlTests/RouteGeometryTests.swift`
- `RoamControlTests/HumanizedMotionModelTests.swift`
- `RoamControlTests/RouteRunnerTests.swift`
- `RoamControlTests/RouteStoreTests.swift`
- `RoamControlTests/RouteLibraryModelTests.swift`
- `RoamControlTests/RouteEditorModelTests.swift`
- `RoamControlTests/RouteProfileStoreTests.swift`
- `RoamControlTests/RouteSessionModelTests.swift`
- `RoamControlTests/RouteRecoveryTests.swift`

Modified integration files:

- `RoamControl.xcodeproj/project.pbxproj`
- `RoamControl/Models/SessionRecoveryRecord.swift`
- `RoamControl/App/AppModel.swift`
- `RoamControl/Features/Map/MapViewModel.swift`
- `RoamControl/Features/Home/HomeView.swift`
- `RoamControl/Features/Home/SessionRecoveryView.swift`

---

### Task 1: Add the XCTest target and baseline smoke test

**Files:**
- Modify: `roam-src/RoamControl.xcodeproj/project.pbxproj`
- Create: `roam-src/RoamControlTests/BaselineTests.swift`

**Interfaces:**
- Produces a test bundle named `RoamControlTests`.
- Uses `@testable import RoamControl`.
- Test command used by later tasks:

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests \
  CODE_SIGNING_ALLOWED=NO
```

**Step 1: Confirm the existing project and scheme**

Run:

```bash
cd E:/Ai_Agent/RUN/roam-src
xcodebuild -list -project RoamControl.xcodeproj
```

Expected: one app target and one shared `RoamControl` scheme.

**Step 2: Add the unit-test target**

Edit `RoamControl.xcodeproj/project.pbxproj` to add a `RoamControlTests` native target, product reference, source build phase, target dependency on `RoamControl`, and the `RoamControlTests` group. Set:

```text
PRODUCT_BUNDLE_IDENTIFIER = com.sean.roamcontrol.tests
IPHONEOS_DEPLOYMENT_TARGET = 27.0
SWIFT_VERSION = 5.0
GENERATE_INFOPLIST_FILE = YES
BUNDLE_LOADER = "$(TEST_HOST)"
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/RoamControl.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RoamControl"
```

Add the test target to the shared `RoamControl` scheme's Test action.

**Step 3: Write the baseline test**

Create `RoamControlTests/BaselineTests.swift`:

```swift
import XCTest
@testable import RoamControl

final class BaselineTests: XCTestCase {
    func testLocationTargetPreservesCoordinate() {
        let target = LocationTarget(
            name: "Track",
            subtitle: "Start",
            latitude: 31.2304,
            longitude: 121.4737
        )

        XCTAssertEqual(target.coordinate.latitude, 31.2304, accuracy: 0.000_001)
        XCTAssertEqual(target.coordinate.longitude, 121.4737, accuracy: 0.000_001)
    }
}
```

**Step 4: Run the test**

Run the command from the Interfaces block.

Expected: `BaselineTests` passes and the app target still builds.

**Step 5: Commit**

```bash
git add RoamControl.xcodeproj/project.pbxproj RoamControlTests/BaselineTests.swift
git commit -m "test: add RoamControl unit test target"
```

---

### Task 2: Implement route coordinates and closed-loop geometry

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/Models/GeoCoordinate.swift`
- Create: `roam-src/RoamControl/Features/Routes/Models/RouteDefinition.swift`
- Create: `roam-src/RoamControl/Features/Routes/Models/RouteGeometry.swift`
- Create: `roam-src/RoamControlTests/RouteGeometryTests.swift`

**Interfaces:**

```swift
struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool { get }
    func distance(to other: GeoCoordinate) -> Double
}

enum RouteSource: String, Codable, Sendable {
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

enum RouteGeometryError: Error, Equatable {
    case invalidCoordinate
    case tooFewPoints(minimum: Int)
    case zeroLength
}

struct RouteGeometry: Equatable, Sendable {
    let points: [GeoCoordinate]
    let isClosed: Bool
    let segmentLengths: [Double]
    let totalDistance: Double

    init(points: [GeoCoordinate], isClosed: Bool) throws
    func coordinate(atDistance distance: Double) -> GeoCoordinate
}
```

**Step 1: Write failing geometry tests**

Create `RouteGeometryTests.swift` with tests covering:

```swift
func testOpenRouteInterpolatesHalfwayAlongFirstSegment()
func testClosedRouteAddsClosingSegment()
func testClosedRouteReturnsStartAtTotalDistance()
func testConsecutiveNearDuplicatePointsAreCollapsed()
func testInvalidCoordinateThrows()
func testTooFewEffectivePointsThrows()
func testZeroLengthRouteThrows()
func testThousandLoopReuseStaysNumericallyStable()
```

Use a small square around a fixed coordinate. The midpoint assertion should compare against the expected interpolated latitude/longitude with `0.000_001` accuracy. The thousand-loop test should call `coordinate(atDistance:)` with `totalDistance * loop` and assert the start coordinate remains within `1e-9` degrees.

**Step 2: Run the geometry tests and confirm failure**

Run:

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/RouteGeometryTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because the route types do not exist.

**Step 3: Implement the coordinate and definition models**

`GeoCoordinate.isValid` checks finite latitude in `-90...90` and finite longitude in `-180...180`. `distance(to:)` uses `CLLocation.distance(from:)`; do not use MapKit.

**Step 4: Implement `RouteGeometry`**

Implementation rules:

- Reject invalid or non-finite coordinates before processing.
- Collapse each consecutive pair separated by less than `0.5` metres.
- If closed and the last effective point is not the first, append the first point for segment calculation while preserving `isClosed == true`.
- Build `segmentLengths` for every segment, including the closing segment.
- Throw `.tooFewPoints(minimum: 3)` for closed routes and `.tooFewPoints(minimum: 2)` for open routes after deduplication.
- Throw `.zeroLength` when `totalDistance <= 0`.
- `coordinate(atDistance:)` clamps negative values to zero and values beyond `totalDistance` to the final point.
- Use linear latitude/longitude interpolation inside one segment. The core needs route progress, not geodesic projection; CoreLocation supplies segment distances.

**Step 5: Run the focused tests**

Run the command from Step 2.

Expected: all `RouteGeometryTests` pass.

**Step 6: Build the app target**

```bash
xcodebuild build \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 7: Commit**

```bash
git add RoamControl/Features/Routes/Models RoamControlTests/RouteGeometryTests.swift
git commit -m "feat: add route geometry core"
```

---

### Task 3: Add deterministic humanized speed, cadence, and GPS jitter

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/Models/RunProfile.swift`
- Create: `roam-src/RoamControl/Features/Routes/Core/HumanizedMotionModel.swift`
- Create: `roam-src/RoamControlTests/HumanizedMotionModelTests.swift`

**Interfaces:**

```swift
enum RunProfileValidationError: Error, Equatable {
    case invalidSpeed
    case invalidCadence
    case invalidVariation
    case invalidJitter
}

struct RunProfile: Codable, Equatable, Sendable {
    var targetSpeedMetersPerSecond: Double
    var targetCadenceStepsPerMinute: Double
    var speedVariationFraction: Double
    var cadenceVariationFraction: Double
    var gpsJitterRadiusMeters: Double
    var noiseSeed: UInt64

    static let running: RunProfile
    func validate() throws
}

struct HumanizedMotionModel: Sendable {
    init(seed: UInt64)
    func speedMetersPerSecond(at elapsed: TimeInterval, profile: RunProfile) -> Double
    func cadenceStepsPerMinute(at elapsed: TimeInterval, profile: RunProfile) -> Double
    func reportedCoordinate(
        for groundCoordinate: GeoCoordinate,
        at elapsed: TimeInterval,
        profile: RunProfile
    ) -> GeoCoordinate
}
```

**Step 1: Write failing motion tests**

Create tests for:

```swift
func testProfileRoundTripsThroughCodable()
func testProfileRejectsOutOfRangeValues()
func testSameSeedProducesSameSamples()
func testDifferentSeedsProduceDifferentJitter()
func testSpeedAndCadenceStayWithinConfiguredBounds()
func testZeroJitterReturnsExactGroundCoordinate()
func testJitterNeverExceedsRadius()
func testJitterRemainsSmoothBetweenOneSecondSamples()
```

Default runtime bounds:

```text
speed: 0.5...10.0 m/s
cadence: 60...240 spm
variation fractions: 0...0.35
jitter radius: 0...10 m
```

**Step 2: Run the motion tests and confirm failure**

Use:

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/HumanizedMotionModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because the motion types do not exist.

**Step 3: Implement `RunProfile`**

Use a default running profile:

```text
targetSpeedMetersPerSecond = 2.8
targetCadenceStepsPerMinute = 170
speedVariationFraction = 0.06
cadenceVariationFraction = 0.04
gpsJitterRadiusMeters = 1.5
noiseSeed = 0x524F414D
```

The `validate()` method rejects non-finite values and values outside the documented ranges.

**Step 4: Implement smooth deterministic motion**

Use two or three low-frequency sine components per signal. Derive phase offsets from `noiseSeed` at initialization. Keep the combined multiplier bounded by the configured fraction.

For jitter:

- Build a bounded two-dimensional offset no larger than `gpsJitterRadiusMeters`.
- Convert metres to latitude/longitude locally around the ground coordinate.
- Return the exact ground coordinate when radius is zero.
- Keep the function pure so the same coordinate, elapsed time, profile, and seed return the same output.

Do not use `Double.random`, `SystemRandomNumberGenerator`, or a per-tick random source.

**Step 5: Run the focused tests**

Expected: all `HumanizedMotionModelTests` pass.

**Step 6: Commit**

```bash
git add RoamControl/Features/Routes/Models/RunProfile.swift \
  RoamControl/Features/Routes/Core/HumanizedMotionModel.swift \
  RoamControlTests/HumanizedMotionModelTests.swift
git commit -m "feat: add deterministic route motion model"
```

---

### Task 4: Implement the pure Swift route runner

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/Models/RouteRunMode.swift`
- Create: `roam-src/RoamControl/Features/Routes/Core/RouteRunner.swift`
- Create: `roam-src/RoamControlTests/RouteRunnerTests.swift`

**Interfaces:**

```swift
enum RouteRunMode: Codable, Equatable, Sendable {
    case once
    case laps(Int)
    case continuous

    func validated() throws -> RouteRunMode
}

enum RouteRunnerPhase: Equatable, Sendable {
    case idle
    case running
    case paused
    case finished
}

struct RouteRunProgress: Codable, Equatable, Sendable {
    var distanceInLap: Double
    var completedLaps: Int
    var elapsedTime: TimeInterval
}

struct RouteRunSnapshot: Equatable, Sendable {
    let groundCoordinate: GeoCoordinate
    let reportedCoordinate: GeoCoordinate
    let speedMetersPerSecond: Double
    let cadenceStepsPerMinute: Double
    let distanceInLap: Double
    let totalDistance: Double
    let completedLaps: Int
    let elapsedTime: TimeInterval
    let phase: RouteRunnerPhase
}

struct RouteRunner: Sendable {
    let geometry: RouteGeometry
    let profile: RunProfile
    let mode: RouteRunMode

    private(set) var phase: RouteRunnerPhase
    private(set) var snapshot: RouteRunSnapshot

    init(
        geometry: RouteGeometry,
        profile: RunProfile,
        mode: RouteRunMode,
        progress: RouteRunProgress = .init(distanceInLap: 0, completedLaps: 0, elapsedTime: 0)
    )

    mutating func start()
    mutating func pause()
    mutating func resume()
    mutating func advance(by delta: TimeInterval) -> RouteRunSnapshot
}
```

**Step 1: Write failing runner tests**

Create tests for:

```swift
func testStartsAtFirstRouteCoordinate()
func testPauseDoesNotAdvanceProgress()
func testResumeContinuesFromPausedCoordinate()
func testFiniteLapRunFinishesAfterRequestedLapCount()
func testOpenRouteFinishesAtFinalCoordinate()
func testContinuousRouteWrapsWithoutASeamJump()
func testCompletedLapIncrementsExactlyOnceAtSeam()
func testLargeAdvanceCanCrossMultipleLaps()
func testThousandLapsDoNotAccumulateLapError()
func testProgressInitializerRestoresMidLapPosition()
```

For seam continuity, compare the coordinate immediately before and immediately after the first lap boundary and require their separation to be below the distance covered in one second plus a small tolerance.

**Step 2: Run the runner tests and confirm failure**

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/RouteRunnerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because the runner does not exist.

**Step 3: Implement mode validation**

- `.once` is valid for any route and runs from the start to the route end.
- `.laps(count)` requires `count >= 1` and a closed route; otherwise throw an invalid-mode error defined alongside `RouteRunMode`.
- `.continuous` requires a closed route.
- The open-route initializer always treats `.continuous` and `.laps` as invalid, making impossible states explicit.

**Step 4: Implement runner advancement**

On each `advance(by:)`:

1. Ignore non-positive or non-finite deltas.
2. Do nothing unless `phase == .running`.
3. Calculate the humanized target speed at `elapsedTime + delta`.
4. Advance ground distance by `speed * delta`.
5. For open routes, clamp at `geometry.totalDistance` and finish.
6. For closed routes, divide total distance by route length, increment `completedLaps` by the whole number of seam crossings, and use only the remainder as `distanceInLap`.
7. Finish finite runs when the requested lap count is reached.
8. Sample the ground coordinate from `RouteGeometry`.
9. Sample the reported coordinate through `HumanizedMotionModel`.
10. Update `snapshot` and return it.

Do not cap tick time in the runner. The session model will pass wall-clock elapsed time so delayed ticks still preserve correct run progress.

**Step 5: Run the focused tests**

Expected: all `RouteRunnerTests` pass.

**Step 6: Run the full route-core suite**

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/RouteGeometryTests \
  -only-testing:RoamControlTests/HumanizedMotionModelTests \
  -only-testing:RoamControlTests/RouteRunnerTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass.

**Step 7: Commit**

```bash
git add RoamControl/Features/Routes/Models/RouteRunMode.swift \
  RoamControl/Features/Routes/Core/RouteRunner.swift \
  RoamControlTests/RouteRunnerTests.swift
git commit -m "feat: add looping route runner"
```

---

### Task 5: Persist the route library safely

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/Storage/RouteStore.swift`
- Create: `roam-src/RoamControlTests/RouteStoreTests.swift`

**Interfaces:**

```swift
enum RouteStoreError: Error, Equatable {
    case unsupportedSchema(Int)
    case corruptedFile
    case writeFailed
}

struct RouteStore: Sendable {
    static let currentSchemaVersion = 1
    static var liveFileURL: URL { get }

    let fileURL: URL
    init(fileURL: URL = Self.liveFileURL)

    func load() throws -> [RouteDefinition]
    func save(_ routes: [RouteDefinition]) throws
}
```

The encoded document is:

```swift
private struct RouteLibraryDocument: Codable {
    let schemaVersion: Int
    let routes: [RouteDefinition]
}
```

**Step 1: Write failing store tests**

Use a unique temporary directory per test. Cover:

```swift
func testMissingFileLoadsAsEmptyLibrary()
func testSaveAndLoadRoundTripsRoutes()
func testSaveCreatesParentDirectory()
func testCorruptedFileThrowsAndRemainsUnchanged()
func testUnsupportedSchemaThrows()
func testSaveUsesAtomicReplacement()
```

For the corruption test, write invalid JSON, call `load()`, assert the error, then read the file bytes and assert they still match the invalid input.

**Step 2: Run the store tests and confirm failure**

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/RouteStoreTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because `RouteStore` does not exist.

**Step 3: Implement storage**

- `liveFileURL` resolves Application Support, appends `RoamControl`, then `routes.json`.
- Create the parent directory before writing.
- Encode with ISO-8601 dates and sorted keys.
- Read missing files as an empty array.
- Decode existing files with ISO-8601 dates.
- If JSON syntax or shape is invalid, throw `.corruptedFile` and do not write a replacement.
- If schema version is greater than `currentSchemaVersion`, throw `.unsupportedSchema`.
- Write with `Data.WriteOptions.atomic`.

**Step 4: Run the focused tests**

Expected: all `RouteStoreTests` pass.

**Step 5: Commit**

```bash
git add RoamControl/Features/Routes/Storage/RouteStore.swift \
  RoamControlTests/RouteStoreTests.swift
git commit -m "feat: persist route library atomically"
```

---

### Task 6: Add the route-library state model

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/State/RouteLibraryModel.swift`
- Create: `roam-src/RoamControlTests/RouteLibraryModelTests.swift`

**Interfaces:**

```swift
@MainActor
@Observable
final class RouteLibraryModel {
    private(set) var routes: [RouteDefinition]
    private(set) var isLoading: Bool
    private(set) var errorMessage: String?

    init(store: RouteStore = RouteStore())

    func load()
    func upsert(_ route: RouteDefinition)
    func delete(id: UUID)
    func route(id: UUID) -> RouteDefinition?
    func clearError()
}
```

**Step 1: Write failing library-model tests**

Annotate the test class `@MainActor`. Cover:

```swift
func testLoadSortsRoutesByUpdatedAtDescending()
func testUpsertAddsAndReplacesByStableID()
func testUpsertTrimsNameAndRejectsEmptyName()
func testDeleteRemovesOnlyRequestedRoute()
func testFailedSaveKeepsPreviousInMemoryState()
func testCorruptedStoreExposesErrorWithoutClearingRoutes()
```

Use a small test double only by supplying a temporary-file `RouteStore`; do not introduce a one-method storage protocol.

**Step 2: Run tests and confirm failure**

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/RouteLibraryModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure.

**Step 3: Implement the model**

- Load during initialization.
- Keep routes sorted by `updatedAt`, newest first; use `id.uuidString` as a stable tie-breaker.
- Trim route names before save and reject empty names with `errorMessage = "Route name cannot be empty."`.
- Build the next candidate array, save it, and only replace `routes` after a successful write.
- Keep the previous in-memory list when save or delete fails.
- A load failure sets `errorMessage` and leaves routes empty; it must not write to the store.

**Step 4: Run the focused tests**

Expected: all `RouteLibraryModelTests` pass.

**Step 5: Commit**

```bash
git add RoamControl/Features/Routes/State/RouteLibraryModel.swift \
  RoamControlTests/RouteLibraryModelTests.swift
git commit -m "feat: add route library state"
```

---

### Task 7: Add the route-editor state model

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/State/RouteEditorModel.swift`
- Create: `roam-src/RoamControlTests/RouteEditorModelTests.swift`

**Interfaces:**

```swift
@MainActor
@Observable
final class RouteEditorModel {
    var name: String
    private(set) var points: [GeoCoordinate]
    var isClosed: Bool
    private(set) var errorMessage: String?

    init(route: RouteDefinition? = nil)

    var canSave: Bool { get }
    var effectivePointCount: Int { get }
    var totalDistance: Double { get }
    var canUndo: Bool { get }

    func appendPoint(_ coordinate: GeoCoordinate)
    func undoLastPoint()
    func clear()
    func makeRoute(existing: RouteDefinition? = nil) throws -> RouteDefinition
}
```

**Step 1: Write failing editor-model tests**

Cover:

```swift
func testNewEditorStartsWithClosedModeAndDefaultName()
func testAppendPointIgnoresConsecutivePointsCloserThanHalfMetre()
func testUndoRemovesOnlyLastPoint()
func testClearRemovesAllPoints()
func testCanSaveRequiresMinimumEffectivePoints()
func testClosedRouteRequiresThreeEffectivePoints()
func testSavePreservesExistingIDAndCreationDate()
func testSaveRejectsBlankName()
```

**Step 2: Run tests and confirm failure**

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/RouteEditorModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure.

**Step 3: Implement the editor model**

- New editor defaults: name `New Route`, `isClosed = true`, no points.
- `appendPoint` validates the coordinate and rejects a point within 0.5 metres of the previous point.
- `effectivePointCount` applies the same consecutive-duplicate rule used by route geometry.
- `canSave` constructs a temporary `RouteGeometry` and returns whether it succeeds.
- `makeRoute` trims the name, preserves `id` and `createdAt` when editing, and sets `updatedAt = .now`.
- New route source is `.drawn`.
- Error messages remain English and state the minimum point requirement.

**Step 4: Run the focused tests**

Expected: all `RouteEditorModelTests` pass.

**Step 5: Commit**

```bash
git add RoamControl/Features/Routes/State/RouteEditorModel.swift \
  RoamControlTests/RouteEditorModelTests.swift
git commit -m "feat: add manual route editor state"
```

---

### Task 8: Build the manual route editor UI

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/Views/RouteEditorView.swift`

**Interfaces:**

```swift
struct RouteEditorView: View {
    let existingRoute: RouteDefinition?
    let onSave: (RouteDefinition) -> Void
    let onCancel: () -> Void
}
```

**Step 1: Build the screen**

Use a `NavigationStack` containing:

- A full-screen `MapReader` map.
- Existing points rendered as a `MapPolyline`.
- Each point rendered as a small marker.
- A tap gesture that converts the local point through `MapReader` and calls `model.appendPoint`.
- A top name field.
- A bottom editor panel with effective point count, total distance, closed-loop toggle, Undo, Clear, Cancel, and Save.
- Save disabled while `model.canSave` is false.
- A confirmation before clearing a non-empty route.
- Dynamic Type support by putting editor controls in a scrollable panel at accessibility sizes.

The editor map uses an editing camera region derived from existing points. Do not call `MapViewModel.selectDroppedPin` while editing.

**Step 2: Add accessibility labels**

At minimum:

```text
Route name
Closed loop
Undo last point
Clear route
Cancel route editing
Save route
```

**Step 3: Build**

```bash
xcodebuild build \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

**Step 4: Manual simulator check**

- Draw a four-point rectangle.
- Confirm the closing segment appears when `Closed loop` is on.
- Undo one point and confirm the line and save state update.
- Save and inspect the callback in the library flow added by Task 9.

**Step 5: Commit**

```bash
git add RoamControl/Features/Routes/Views/RouteEditorView.swift
git commit -m "feat: add manual route editor UI"
```

---

### Task 9: Add the route library and run-setup UI

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/Views/RouteLibraryView.swift`
- Create: `roam-src/RoamControl/Features/Routes/Views/RouteRunSetupView.swift`

**Interfaces:**

```swift
struct RouteRunConfiguration: Equatable, Sendable {
    let route: RouteDefinition
    let profile: RunProfile
    let mode: RouteRunMode
}

struct RouteLibraryView: View {
    let isRouteActive: Bool
    let isPaired: Bool
    let onRun: (RouteRunConfiguration) -> Void
    let onClose: () -> Void
    let onEditActiveRoute: () -> Void
}
```

`RouteLibraryView` owns a `@State RouteLibraryModel`. `RouteRunSetupView` owns editable profile state and a mode choice, and receives `isPaired` from the library view.

**Step 1: Add the route profile preferences store**

Inside `RouteRunSetupView.swift`, add a small `RunProfileStore` using injected `UserDefaults`:

```swift
struct RunProfileStore {
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard)
    func load() -> RunProfile
    func save(_ profile: RunProfile)
}
```

Use one `Data` key and fall back to `.running` for missing or invalid data. Do not add a protocol.

**Step 2: Build the library**

- `NavigationStack` list of routes.
- Each row shows route name, formatted distance, closed/open status, and last-updated time.
- Empty state says: `Draw a route to start a repeatable run.`
- Toolbar `New Route` opens `RouteEditorView`.
- Tap a route to open `RouteRunSetupView`.
- Swipe actions can rename and delete.
- Disable edit and delete for the active route in this phase; show `Stop the active run before changing this route.`
- On editor save, call `RouteLibraryModel.upsert` and dismiss the editor.

**Step 3: Build run setup**

Controls:

- Target speed slider: 1.0...6.0 m/s.
- Cadence slider: 120...210 spm.
- Speed variation slider: 0...15%.
- Cadence variation slider: 0...15%.
- GPS jitter slider: 0...5 m.
- Mode picker: `Once`, `Continuous`, `Laps`.
- Lap-count stepper visible only for `Laps`; range 1...100.
- For open routes, force `Once`.
- For closed routes, default to `Continuous`.
- Start disabled unless the route geometry is valid and pairing is complete.

The run button returns `RouteRunConfiguration` through `onRun`; it does not start the session itself.

**Step 4: Add profile-store tests**

Create `RoamControlTests/RouteProfileStoreTests.swift` and verify round-trip plus invalid-data fallback using a unique `UserDefaults(suiteName:)`.

Run:

```bash
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests/RouteProfileStoreTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both tests pass.

**Step 5: Build and inspect**

Build for the simulator. Manually verify empty state, create, rename, delete, and run-setup defaults for closed/open routes.

**Step 6: Commit**

```bash
git add RoamControl/Features/Routes/Views/RouteLibraryView.swift \
  RoamControl/Features/Routes/Views/RouteRunSetupView.swift \
  RoamControlTests/RouteProfileStoreTests.swift
git commit -m "feat: add route library and run setup"
```

---

### Task 10: Connect the runner to the device session

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/State/RouteSessionModel.swift`
- Modify: `roam-src/RoamControl/Models/SessionRecoveryRecord.swift`
- Modify: `roam-src/RoamControl/App/AppModel.swift`
- Create: `roam-src/RoamControlTests/RouteRecoveryTests.swift`
- Create: `roam-src/RoamControlTests/RouteSessionModelTests.swift`

**Interfaces:**

```swift
enum RouteSessionPhase: Equatable {
    case idle
    case preparing
    case running
    case paused
    case finished
    case stopping
    case failed(String)
}

@MainActor
@Observable
final class RouteSessionModel {
    private(set) var phase: RouteSessionPhase
    private(set) var route: RouteDefinition?
    private(set) var snapshot: RouteRunSnapshot?
    private(set) var errorMessage: String?

    var locksRouteInput: Bool { get }
    var completedLaps: Int { get }
    var lapProgress: Double { get }
    var totalDistance: Double { get }

    func prepare(
        route: RouteDefinition,
        profile: RunProfile,
        mode: RouteRunMode,
        progress: RouteRunProgress
    ) throws
    func start(using appModel: AppModel) async
    func togglePause()
    func stop(using appModel: AppModel)
    func handleDeviceSessionPhase(
        _ phase: DeviceSessionPhase,
        appModel: AppModel
    )
    func reset()
}
```

Extend `SessionRecoveryRecord.Kind` with `.savedRoute`; add these optional fields with `nil` defaults so existing memberwise initialization and old JSON remain compatible:

```swift
var savedRoute: RouteDefinition? = nil
var routeProgress: RouteRunProgress? = nil
var runProfile: RunProfile? = nil
var runMode: RouteRunMode? = nil
```

Add:

```swift
var isSavedRoute: Bool
var isRouteSession: Bool

static func savedRoute(
    route: RouteDefinition,
    at initialTarget: LocationTarget,
    progress: RouteRunProgress,
    profile: RunProfile,
    mode: RouteRunMode
) -> SessionRecoveryRecord
```

Add to `AppModel`:

```swift
func startRouteLocationSession(
    at initialTarget: LocationTarget,
    route: RouteDefinition,
    profile: RunProfile,
    mode: RouteRunMode
) async
func updateActiveRouteRecovery(
    at target: LocationTarget,
    progress: RouteRunProgress
)
func finishActiveRouteRecovery(at target: LocationTarget)
```

**Step 1: Extend persisted recovery before connecting the session**

- Add the new kind and optional snapshot fields.
- Preserve every existing factory and fixed/walking semantic.
- `isRouteSession` returns true for `.walkingRoute` and `.savedRoute`.
- The saved-route factory stores the full `RouteDefinition`, initial progress, profile, and mode.
- Set optional properties to `nil` by default instead of requiring edits at existing memberwise call sites.
- Add `updateActiveRouteRecovery` to update last position, progress, and timestamp while preserving the route snapshot.
- Add `finishActiveRouteRecovery` to replace the completed route recovery with a fixed-position record at the final target.

**Step 2: Add backward-compatibility tests first**

Create `RouteRecoveryTests.swift` with:

```swift
func testExistingFixedLocationRecordStillDecodes()
func testExistingWalkingRecordStillDecodes()
func testSavedRouteRecordRoundTripsSnapshotAndProgress()
func testSavedRouteRecordContainsRouteGeometry()
func testRouteModeAndProfileRemainDeterministicAfterDecoding()
```

For legacy JSON, encode a dictionary matching the current fields exactly, decode it, and assert the new optional fields are nil. Run only `RouteRecoveryTests`; it should fail before the model extension compiles, then pass after Step 1.

**Step 3: Add the AppModel start boundary**

This method calls the existing private `startLocationSession` with:

- Device target: the runner's initial ground coordinate represented as `LocationTarget`, including when resuming mid-route.
- Selected target: a `LocationTarget` named after the route.
- History target: the same initial ground coordinate.
- Recovery: the `.savedRoute(...)` factory with zero or restored progress, profile, and mode.

Do not use a fixed-location recovery for a manual route run.

**Step 4: Implement session preparation**

`prepare`:

- Builds `RouteGeometry`.
- Validates `RunMode`.
- Validates `RunProfile`.
- Creates `RouteRunner` at the supplied progress.
- Sets current coordinate display from `snapshot.groundCoordinate`.
- Sets phase `.idle`.

**Step 5: Implement starting and movement**

`start(using:)`:

- Reject when not paired with `Pair this iPhone before starting a route.`
- Set `.preparing`.
- Call `appModel.startRouteLocationSession`.
- If the device remains idle, set `.failed("Roam Control could not start the route session.")`.

On device `.active`, start a `@MainActor` task. Track wall-clock time with `Date.now`, sleep approximately one second, and pass the real elapsed interval to `RouteRunner.advance(by:)`.

For each snapshot:

- Convert `reportedCoordinate` to `LocationTarget`.
- Name it `Running <route name>`.
- Set subtitle to `<laps> laps · <speed> m/s · <cadence> spm`.
- Call `appModel.deviceSession.updateLocation(target)`.
- Enter `.failed("The active location session ended before the route finished.")` unless the result is `.updated`.
- Enter `.finished` when the runner finishes.
- On finish, convert the active recovery to a fixed-location recovery so a crash cannot lose the last simulated point.

**Step 6: Implement pause, resume, stop, and failure propagation**

- Pausing stops distance advancement but leaves the device at the last reported coordinate and resets the tick reference.
- Resume restarts from the same runner progress.
- Stop cancels the task, enters `.stopping`, and calls `deviceSession.stop()`.
- Device `.idle` after `.stopping` resets coordinates and phase.
- Device `.failed(message)` enters `.failed(message)` and cancels movement immediately.
- There must never be continued `updateLocation` calls after failure or finish.

**Step 7: Add pure session tests where practical**

Do not mock `LocalDeviceSessionCoordinator`. Test profile/mode/first-target derivation as pure helpers if they are extracted. The runner itself remains the primary tested unit. Add one `RouteSessionModel` test that `prepare` fails for an invalid mode before any device call.

**Step 8: Build**

Run the full app build for the simulator.

Expected: build succeeds and the Apple walking controller still compiles unchanged.

**Step 9: Commit**

```bash
git add RoamControl/Features/Routes/State/RouteSessionModel.swift \
  RoamControl/Models/SessionRecoveryRecord.swift \
  RoamControl/App/AppModel.swift \
  RoamControlTests/RouteRecoveryTests.swift \
  RoamControlTests/RouteSessionModelTests.swift
git commit -m "feat: connect route runner to device session"
```

---

### Task 11: Hook route progress into recovery during active runs

**Files:**
- Modify: `roam-src/RoamControl/App/AppModel.swift`
- Modify: `roam-src/RoamControl/Features/Routes/State/RouteSessionModel.swift`
- Modify: `roam-src/RoamControlTests/RouteRecoveryTests.swift`

**Interfaces:**
- Use the `updateActiveRouteRecovery(at:progress:)` and `finishActiveRouteRecovery(at:)` boundaries added in Task 10.
- Recovery keeps the route snapshot, profile, mode, completed laps, within-lap distance, and elapsed time.

**Step 1: Persist accepted movement snapshots**

After `deviceSession.updateLocation(target)` returns `.updated`:

- Call `appModel.updateActiveRouteRecovery` with the accepted target and `RouteRunProgress` from the runner.
- Keep the route snapshot unchanged.
- Rely on the existing AppModel five-second throttle rather than adding a second timer.

Do not write progress while paused, preparing, failed, or after the run finishes.

**Step 2: Finalize and clear recovery consistently**

- On a completed finite run, call `finishActiveRouteRecovery` with the last reported target.
- On user stop, let the existing device stop path restore the real location and clear active recovery.
- On device failure, preserve the last saved route recovery so the next launch can offer resume or real-location restore.
- A route name that equals a destination name must never silently convert `.savedRoute` to `.fixed`.

**Step 3: Add focused recovery assertions**

Extend `RouteRecoveryTests` to verify:

```swift
func testUpdatingProgressPreservesRouteSnapshot()
func testCompletedRunConvertsRecoveryToFinalFixedLocation()
func testFailedRunRetainsSavedRouteRecovery()
```

Run `RouteRecoveryTests`, then the full `RoamControlTests` suite.

**Step 4: Build**

Run the full app build for the simulator and confirm the Apple walking controller still compiles unchanged.

**Step 5: Commit**

```bash
git add RoamControl/App/AppModel.swift \
  RoamControl/Features/Routes/State/RouteSessionModel.swift \
  RoamControlTests/RouteRecoveryTests.swift
git commit -m "feat: persist route progress during runs"
```

---

### Task 12: Add the route run card and wire the route flow into Home

**Files:**
- Create: `roam-src/RoamControl/Features/Routes/Views/RouteRunCard.swift`
- Modify: `roam-src/RoamControl/Features/Map/MapViewModel.swift`
- Modify: `roam-src/RoamControl/Features/Home/HomeView.swift`

**Interfaces:**

```swift
struct RouteRunCard: View {
    let route: RouteDefinition
    let session: RouteSessionModel
    let isPaired: Bool
    let onStart: () -> Void
    let onTogglePause: () -> Void
    let onStop: () -> Void
    let onDone: () -> Void
}
```

Add to `MapViewModel`:

```swift
func show(_ geometry: RouteGeometry)
```

**Step 1: Add route camera framing**

Build an `MKCoordinateRegion` from route coordinates, add 25% padding, and assign it to `cameraPosition`. Handle a one-point or invalid region defensively even though saved routes have at least two effective points.

**Step 2: Build `RouteRunCard`**

Show:

- Route name and phase title.
- Completed laps.
- Lap progress.
- Total distance.
- Current speed in m/s.
- Current cadence in spm.
- Elapsed time.
- Start, Pause/Resume, Stop & Restore, and Done controls.
- A stop confirmation explaining that the real location will be restored.

Use a compact layout matching the existing `WalkingRoutePreviewCard`, with a scrollable card at accessibility Dynamic Type sizes. Include an overflow menu for destructive actions only when needed; keep Pause/Resume as the prominent action.

**Step 3: Add Home state and entry point**

Add:

```swift
@State private var routeSession = RouteSessionModel()
@State private var isShowingRouteLibrary = false
@State private var routeLibraryError: String?
```

Add a route-library button beside Favourites and Settings using the `point.topleft.down.to.point.bottomright.curvepath` SF Symbol. Present `RouteLibraryView` in a sheet.

When `RouteLibraryView` returns a configuration:

1. Dismiss the library.
2. Reset Apple walking state and clear its route.
3. Call `routeSession.prepare(...)` with zero progress.
4. Show the new route geometry on the map.
5. Start the route session.

If route preparation fails, keep the library open or surface `routeLibraryError`; do not start the device session.

**Step 4: Render route state on the map**

- Draw the active route geometry as a blue `MapPolyline`.
- Draw the route's reported coordinate with a running annotation.
- Disable ordinary map-tap reverse geocoding while `routeSession.locksRouteInput`.
- Do not draw the Apple `MKRoute` and manual route simultaneously.
- Clear the selected fixed location when a manual run starts.

**Step 5: Coordinate cards and device phases**

Card precedence:

1. Real-location restoration card.
2. Route run card when a manual route is prepared or active.
3. Apple walking card.
4. Location selection card.

Forward `appModel.deviceSession.phase` changes to both `walkingSimulation` and `routeSession`, but only the active flow should react. Ensure route session phase changes do not accidentally reset the fixed-location UI.

**Step 6: Handle done and top-level mode switching**

- `Done` after finish resets route session state, clears the manual polyline, and shows the last simulated target or real location as appropriate.
- Starting a fixed-location session clears manual route state.
- Opening the route library while an active route exists is allowed, but editing/deleting the active route is disabled by Task 9.
- The existing search, favourite, history, settings, pairing, and Apple route actions remain functional outside a locked route run.

**Step 7: Build and run the manual simulator flow**

Use a saved closed route and verify:

- Start prepares the device.
- The first coordinate is visible.
- Pause freezes the coordinate.
- Resume continues.
- Stop enters `.stopping` and restores the device.
- The fixed-location flow still starts and stops normally.

**Step 8: Commit**

```bash
git add RoamControl/Features/Routes/Views/RouteRunCard.swift \
  RoamControl/Features/Map/MapViewModel.swift \
  RoamControl/Features/Home/HomeView.swift
git commit -m "feat: integrate manual routes into Home"
```

---

### Task 13: Restore interrupted route runs

**Files:**
- Modify: `roam-src/RoamControl/Features/Home/HomeView.swift`
- Modify: `roam-src/RoamControl/Features/Home/SessionRecoveryView.swift`

**Interfaces:**
- Use the existing `SessionRecoveryView` callbacks.
- `HomeView.resumeInterruptedSession(_:)` must branch on `recovery.isSavedRoute` before the Apple walking branch.

**Step 1: Update recovery presentation**

In `SessionRecoveryView`:

- Use the route icon for saved routes.
- Show route name instead of a destination.
- Show completed laps and current lap progress when available.
- Resume title is `Resume Route Run`.
- Summary says Roam Control closed before the saved route run ended.
- The real-location restore action remains unchanged.

Do not show Apple-route-specific language for a saved route.

**Step 2: Implement Home restoration**

For `isSavedRoute`:

1. Require `savedRoute`, `runProfile`, `runMode`, and `routeProgress`.
2. Clear `recoveredWalkError`.
3. Reset Apple walking state.
4. Call `routeSession.prepare` with the saved snapshot and progress.
5. Show the saved route on the map.
6. Dismiss the interrupted-session overlay.
7. Start the device session.
8. If any snapshot field is missing or invalid, show `The saved route run could not be restored.` and leave the real-location restore option available.

The restoration must not look up the route by ID or replace it with an Apple route.

**Step 3: Preserve fixed and Apple walking recovery**

- Fixed location follows the existing one-shot location start.
- Apple walking keeps the existing Apple route regeneration behavior.
- Only saved routes use the route snapshot path.

**Step 4: Add recovery tests**

Add model-level tests for a saved route snapshot whose library entry has been deleted. Assert that restoration inputs are still complete. Add an invalid-progress test that throws before any session start.

**Step 5: Build and manually force-quit**

On the simulator:

- Start a saved continuous route.
- Let it cross at least one point.
- Force quit after the five-second recovery save.
- Relaunch.
- Resume and verify lap count and within-lap position continue from the snapshot.

**Step 6: Commit**

```bash
git add RoamControl/Features/Home/HomeView.swift \
  RoamControl/Features/Home/SessionRecoveryView.swift \
  RoamControlTests/RouteRecoveryTests.swift
git commit -m "feat: restore interrupted route runs"
```

---

### Task 14: Run the complete route-system verification

**Files:**
- Modify only if verification exposes a defect.
- Update: `E:\Ai_Agent\RUN\.planning\2026-10-30-roam-route-system\progress.md`

**Step 1: Run the complete unit suite**

```bash
cd E:/Ai_Agent/RUN/roam-src
xcodebuild test \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:RoamControlTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: every test passes.

**Step 2: Build Debug and Release for simulator**

```bash
xcodebuild build \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project RoamControl.xcodeproj \
  -scheme RoamControl \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both configurations succeed without new warnings in route files.

**Step 3: Check the architecture boundary**

Run:

```bash
rg -n "import (SwiftUI|MapKit)|AppModel" RoamControl/Features/Routes/Core RoamControl/Features/Routes/Models
```

Expected: no matches.

Run:

```bash
rg -n "MKRoute|MKMapPoint|MKPolyline" RoamControl/Features/Routes/Core RoamControl/Features/Routes/Models
```

Expected: no matches.

**Step 4: Run the manual acceptance checklist**

Simulator:

- Draw and save a closed rectangle.
- Relaunch and confirm it remains.
- Reopen and confirm identical geometry.
- Rename and delete.
- Start continuous mode.
- Pause for ten seconds and confirm no progress changes.
- Resume.
- Cross the seam at least three times.
- Set jitter to zero and confirm reported markers lie on the route.
- Set jitter to 5 m and confirm movement remains local and continuous.

Physical device:

- Pair and open LocalDevVPN.
- Run a known closed route for at least ten minutes.
- Background the app and verify movement continues at the same lap progress rate.
- Stop and confirm the real location returns.
- Force quit during a run, relaunch, and resume from the saved lap and within-lap distance.
- Confirm the existing fixed-location and Apple walking flows still work.

**Step 5: Update progress and review the diff**

Update `.planning/2026-10-30-roam-route-system/progress.md` with command results, manual checks, and unresolved device-specific issues.

Run:

```bash
git status --short
git diff --stat b68dac0
```

Expected: only route-system, recovery, tests, project-file, and planning-document changes are present. Remove temporary test files and DerivedData produced inside the repository.

**Step 6: Commit verification follow-ups if required**

If verification required a code correction:

```bash
git add <corrected-files>
git commit -m "fix: stabilize route system verification"
```

Do not create an empty verification commit.

---

## Spec Coverage

| Design requirement | Implemented by |
|---|---|
| Save, reload, select, rename, delete routes | Tasks 5, 6, 9 |
| Click-to-draw editor with closed loop | Tasks 7, 8 |
| Closed-route seam and continuous looping | Tasks 2, 4 |
| Deterministic speed, cadence, and bounded jitter | Task 3 |
| Pause, resume, finite and infinite modes | Tasks 4, 10 |
| Device session and real-location restoration | Tasks 10, 12 |
| Recovery with route snapshot and progress | Tasks 11, 13 |
| Existing fixed and Apple walking behavior | Tasks 12, 14 |
| Long-run and physical-device verification | Task 14 |
| GPX and Apple route adapters | Deliberately separate M7 plans |

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-30-manual-running-route-implementation.md`.

Two execution modes:

1. **Subagent-driven:** dispatch one fresh implementation subagent per task, review each result before moving to the next task.
2. **Inline:** execute the tasks in this session using `superpowers:executing-plans`, batching at the planned checkpoints.
