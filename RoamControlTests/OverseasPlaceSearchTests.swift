import MapKit
import XCTest
@testable import RoamControl

/// Task 34: the overseas toggle now asks OpenStreetMap's Nominatim geocoder
/// instead of Apple's map service. Nothing here reaches the network — the decoder
/// is fed fixed bytes, and the view model gets a stand-in `perform`.
final class OverseasPlaceSearchTests: XCTestCase {
    // MARK: - Decoding

    func testDecodesNominatimResultsIntoPlaces() throws {
        let data = try XCTUnwrap(Self.hanedaJSON.data(using: .utf8))

        let places = OverseasPlaceSearch.parse(data)

        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(
            places[0],
            OverseasPlace(
                name: "东京国际机场",
                detail: "羽田空港, 大田区, 东京都, 144-0041, 日本",
                latitude: 35.549399,
                longitude: 139.779839
            )
        )
        XCTAssertEqual(places[1].name, "法兰克福机场")
        XCTAssertEqual(places[1].detail, "法兰克福, 黑森, 德国")
    }

    func testSkipsEntriesWithUnparsableCoordinates() throws {
        let data = try XCTUnwrap(Self.partlyBrokenJSON.data(using: .utf8))

        let places = OverseasPlaceSearch.parse(data)

        XCTAssertEqual(places.count, 1, "A row whose lat is not a number is dropped, not filled with 0.")
        XCTAssertEqual(places[0].name, "东京国际机场")
    }

    func testMissingNameFallsBackToFirstSegmentOfDisplayName() throws {
        let data = try XCTUnwrap(Self.namelessJSON.data(using: .utf8))

        let places = OverseasPlaceSearch.parse(data)

        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places[0].name, "羽田空港")
        XCTAssertEqual(places[0].detail, "大田区, 东京都")
    }

    // MARK: - View model

    @MainActor
    func testOverseasSuggestionsCarryCoordinates() async throws {
        let model = MapViewModel()
        model.overseasPlaceSearchEnabled = true
        model.overseasSearch = Self.stub([
            OverseasPlace(name: "东京国际机场", detail: "羽田空港, 大田区", latitude: 35.549399, longitude: 139.779839)
        ])

        model.updateSearchQuery("Tokyo haneda airport")

        let suggestions = await Self.waitForSuggestions(model)
        XCTAssertEqual(suggestions.count, 1)
        let coordinate = try XCTUnwrap(suggestions.first?.coordinate)
        XCTAssertEqual(coordinate.latitude, 35.549399)
        XCTAssertEqual(coordinate.longitude, 139.779839)
        XCTAssertEqual(suggestions.first?.title, "东京国际机场")
        XCTAssertEqual(suggestions.first?.subtitle, "羽田空港, 大田区")
    }

    @MainActor
    func testSuggestionsUnchangedWhenOverseasIsOff() async {
        let counter = CallCounter()
        let model = MapViewModel()
        model.overseasPlaceSearchEnabled = false
        model.overseasSearch = Self.stub([], counter: counter)

        model.updateSearchQuery("Tokyo haneda airport")
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        XCTAssertEqual(counter.value, 0, "With the toggle off the completer runs and Nominatim is never asked.")
    }

    @MainActor
    func testSelectingOverseasSuggestionDoesNotCallAppleSearch() async throws {
        let counter = CallCounter()
        let model = MapViewModel()
        model.overseasPlaceSearchEnabled = true
        model.overseasSearch = Self.stub([], counter: counter)

        let suggestion = MapSearchSuggestion(
            title: "东京国际机场",
            subtitle: "羽田空港, 大田区",
            coordinate: CLLocationCoordinate2D(latitude: 35.549399, longitude: 139.779839)
        )
        await model.selectSuggestion(suggestion)

        // Apple's search would have to go out and come back; the point is already here.
        let target = try XCTUnwrap(model.selectedLocation)
        XCTAssertEqual(target.name, "东京国际机场")
        XCTAssertEqual(target.subtitle, "羽田空港, 大田区")
        XCTAssertEqual(target.latitude, 35.549399)
        XCTAssertEqual(target.longitude, 139.779839)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(counter.value, 0)
    }

    /// Task 34F: a list built while the toggle was off has no coordinates, so
    /// selecting it would fall back to Apple's search. Flipping the toggle must
    /// drop that list instead of leaving it one tap away from the old behaviour.
    func testTogglingOverseasSearchDropsStaleSuggestions() async throws {
        let model = MapViewModel()
        model.overseasSearch = Self.stub([])
        model.searchSuggestions = [
            MapSearchSuggestion(title: "东京台球", subtitle: "Apple 给出的建议")
        ]

        let stale = model.searchSuggestions.count
        model.overseasPlaceSearchEnabled = true
        let afterOn = model.searchSuggestions.count
        XCTAssertTrue(
            model.searchSuggestions.isEmpty,
            "Turning the switch on must drop the previous list; got \(afterOn) item(s)."
        )

        model.overseasPlaceSearchEnabled = false
        let afterOff = model.searchSuggestions.count
        XCTAssertTrue(
            model.searchSuggestions.isEmpty,
            "Turning it back off must not resurrect them; got \(afterOff) item(s)."
        )
        XCTAssertNil(model.errorMessage)
        print("TASK34F stale=\(stale) afterOn=\(afterOn) afterOff=\(afterOff)")
    }

    // MARK: - Helpers

    /// The request is debounced by 500 ms, so the test polls instead of sleeping a
    /// fixed time and hoping.
    @MainActor
    private static func waitForSuggestions(
        _ model: MapViewModel,
        timeout: TimeInterval = 3
    ) async -> [MapSearchSuggestion] {
        let deadline = Date().addingTimeInterval(timeout)
        while model.searchSuggestions.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return model.searchSuggestions
    }

    private static func stub(
        _ places: [OverseasPlace],
        counter: CallCounter? = nil
    ) -> OverseasPlaceSearch {
        OverseasPlaceSearch { _, _ in
            counter?.increment()
            return places
        }
    }

    // Two rows of a real `format=jsonv2&limit=8` answer, trimmed to the fields the
    // app reads.
    private static let hanedaJSON = """
    [
      {
        "place_id": 260000000,
        "lat": "35.549399",
        "lon": "139.779839",
        "category": "aeroway",
        "type": "aerodrome",
        "display_name": "东京国际机场, 羽田空港, 大田区, 东京都, 144-0041, 日本",
        "name": "东京国际机场"
      },
      {
        "place_id": 260000001,
        "lat": "50.037933",
        "lon": "8.562152",
        "display_name": "法兰克福机场, 法兰克福, 黑森, 德国",
        "name": "法兰克福机场"
      }
    ]
    """

    private static let partlyBrokenJSON = """
    [
      {
        "lat": "abc",
        "lon": "139.779839",
        "display_name": "损坏的一行, 东京都",
        "name": "损坏的一行"
      },
      {
        "lat": "35.549399",
        "lon": "139.779839",
        "display_name": "东京国际机场, 羽田空港, 大田区",
        "name": "东京国际机场"
      }
    ]
    """

    private static let namelessJSON = """
    [
      {
        "lat": "35.549399",
        "lon": "139.779839",
        "display_name": "羽田空港, 大田区, 东京都"
      }
    ]
    """
}

/// `perform` is `@Sendable`, so the stand-in may be called off the main actor.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func increment() {
        lock.lock()
        stored += 1
        lock.unlock()
    }
}
