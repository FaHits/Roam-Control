import MapKit
import XCTest
@testable import RoamControl

/// Task 32: ask Apple's map service what it actually returns, one question per
/// probe, one grep-able `PROBE ` line per answer.
///
/// Overseas search has been "fixed" twice by guessing (Task 28 dropped the
/// viewport region, Task 29 dropped the completer region and added a retry) and
/// failed on the device both times. Nothing here is a product change: `A` is the
/// only probe that asserts, because a zero there means this runner cannot reach
/// Apple's map service at all, and every other line would then be evidence about
/// the environment rather than about the query. `B`-`F` must pass on zero
/// results; their lines are the deliverable.
final class SearchProbeTests: XCTestCase {
    private static let tokyoRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.5494, longitude: 139.7798),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    // MARK: - MKLocalSearch (A, B, C)

    /// The control. This is the one probe allowed to fail: without a hit on a
    /// domestic landmark the runner has no map service, so a red CI here stops us
    /// from reading "no network" as "the query is wrong".
    func testAControlDomestic() async {
        var items: [MKMapItem] = []
        do {
            items = try await search("上海外滩", region: nil)
            print("PROBE A-control-domestic: \(searchLine(items))")
        } catch {
            print("PROBE A-control-domestic: error=\(sanitized(error.localizedDescription))")
        }

        XCTAssertGreaterThanOrEqual(
            items.count,
            1,
            "PROBE A-control-domestic returned nothing: this runner cannot reach Apple's map service, so probes B-F prove nothing about the query."
        )
    }

    func testBOverseasPlain() async {
        await reportSearch("B-overseas-plain", query: "Tokyo haneda airport", region: nil)
    }

    func testCOverseasRegion() async {
        await reportSearch("C-overseas-region", query: "Tokyo haneda airport", region: Self.tokyoRegion)
    }

    // MARK: - MKLocalSearchCompleter (D, E, F)

    func testDCompleterPlain() {
        reportCompletion(
            "D-completer-plain",
            fragment: "Tokyo haneda airport",
            types: [.address, .pointOfInterest, .query],
            region: nil,
            limit: 5
        )
    }

    func testECompleterRegion() {
        reportCompletion(
            "E-completer-region",
            fragment: "Tokyo haneda airport",
            types: [.address, .pointOfInterest, .query],
            region: Self.tokyoRegion,
            limit: 5
        )
    }

    /// Same query and no region, but one result type per run, so a type that
    /// returns nothing cannot hide behind the other two.
    func testFCompleterTypes() {
        let cases: [(label: String, types: MKLocalSearchCompleter.ResultType)] = [
            ("address", [.address]),
            ("pointOfInterest", [.pointOfInterest]),
            ("query", [.query]),
        ]

        for entry in cases {
            reportCompletion(
                "F-completer-types",
                fragment: "Tokyo haneda airport",
                types: entry.types,
                region: nil,
                limit: 3,
                extra: "types=\(entry.label) ",
                titlesOnly: true
            )
        }
    }

    // MARK: - Locale (G)

    /// No network. Records what the simulator thinks it is, so a locale difference
    /// between CI and the device stays visible instead of being assumed away.
    func testGLocale() {
        let languages = Locale.preferredLanguages.joined(separator: " ")
        let localizations = Bundle.main.preferredLocalizations.joined(separator: " ")
        print(
            "PROBE G-locale: Locale.current=\(Locale.current.identifier) "
                + "preferredLanguages=[\(languages)] "
                + "TimeZone.current=\(TimeZone.current.identifier) "
                + "Bundle.main.preferredLocalizations=[\(localizations)]"
        )
    }

    // MARK: - Chinese queries (H)

    /// The device failure this task exists for: on the phone `东京塔` came back as
    /// domestic shops. Same completer settings as `D` — no region, all three result
    /// types — so the only thing that differs from a working run is the query (and,
    /// in the second CI run, the locale). Two lines, one per query.
    func testHChineseQuery() {
        for query in ["东京塔", "羽田机场"] {
            reportCompletion(
                "H-chinese-query",
                fragment: query,
                types: [.address, .pointOfInterest, .query],
                region: nil,
                limit: 3,
                extra: "query=\(query) "
            )
        }
    }

    // MARK: - MapViewModel (I, J)

    /// `A`-`H` talk to MapKit directly. The device fails inside the app's own search
    /// path, so these two drive `MapViewModel` the way the search field does and
    /// print what the list would have shown. `I` is the overseas query with the
    /// setting on; `J` is the same path with it off and a domestic query, so a `J`
    /// that works and an `I` that does not is a chain problem, not a dead service.
    func testIViewModelOverseas() async {
        await reportViewModel(
            "I-viewmodel-overseas",
            query: "Tokyo haneda airport",
            overseas: true
        )
    }

    func testJViewModelDomesticControl() async {
        await reportViewModel(
            "J-viewmodel-domestic-control",
            query: "上海外滩",
            overseas: false
        )
    }

    // MARK: - Helpers

    /// One query through the app's own entry points — `updateSearchQuery`,
    /// `searchSuggestions`, `search`, `selectedLocation`, `errorMessage` — and one
    /// `PROBE ` line. Both waits are capped at three seconds. `search` itself has no
    /// timeout, so it runs in a task the deadline can abandon; a timeout prints its
    /// own line and still passes, because this is evidence, not a gate.
    ///
    /// `MapViewModel` keeps no `searchResults` array: a search either lands in
    /// `selectedLocation` (one place) or in `errorMessage`, so `results` is 0 or 1.
    @MainActor
    private func reportViewModel(_ name: String, query: String, overseas: Bool) async {
        let model = MapViewModel()
        model.overseasPlaceSearchEnabled = overseas
        model.updateSearchQuery(query)

        // Suggestions arrive on the completer's own delegate callback; wait for the
        // first batch, but never longer than the deadline.
        let suggestionDeadline = Date().addingTimeInterval(3)
        while model.searchSuggestions.isEmpty, Date() < suggestionDeadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let suggestions = model.searchSuggestions

        let search = Task { await model.search() }
        let resultDeadline = Date().addingTimeInterval(3)
        var settled = false
        while Date() < resultDeadline {
            if model.selectedLocation != nil || model.errorMessage != nil {
                settled = true
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        guard settled else {
            search.cancel()
            print("PROBE \(name): timeout suggestions=\(suggestions.count) search=no answer in 3s")
            return
        }
        await search.value

        let suggestionText = suggestions
            .prefix(3)
            .map { "\(sanitized($0.title)) ‖ \(sanitized($0.subtitle))" }
            .joined(separator: " | ")
        let target = model.selectedLocation
        let targetText = target.map { "\(sanitized($0.name)) ‖ \(sanitized($0.subtitle))" } ?? ""
        print(
            "PROBE \(name): suggestions=\(suggestions.count) first=[\(suggestionText)] "
                + "results=\(target == nil ? 0 : 1) first=[\(targetText)] "
                + "error=\(sanitized(model.errorMessage))"
        )
    }

    private func search(_ query: String, region: MKCoordinateRegion?) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region {
            request.region = region
        }
        return try await MKLocalSearch(request: request).start().mapItems
    }

    private func reportSearch(_ name: String, query: String, region: MKCoordinateRegion?) async {
        do {
            let items = try await search(query, region: region)
            print("PROBE \(name): \(searchLine(items))")
        } catch {
            print("PROBE \(name): error=\(sanitized(error.localizedDescription))")
        }
    }

    private func searchLine(_ items: [MKMapItem]) -> String {
        let names = items.prefix(3).map { sanitized($0.name) }.joined(separator: " | ")
        let regionName = items.first?.addressRepresentations?.regionName
        return "count=\(items.count) names=[\(names)] region0=\(sanitized(regionName))"
    }

    private func reportCompletion(
        _ name: String,
        fragment: String,
        types: MKLocalSearchCompleter.ResultType,
        region: MKCoordinateRegion?,
        limit: Int,
        extra: String = "",
        titlesOnly: Bool = false
    ) {
        let probe = CompleterProbe(resultTypes: types, region: region)
        let firstAnswer = expectation(description: "\(name) first answer")

        // A completer can call back more than once; fulfilling twice would crash
        // the runner instead of printing a line.
        var answered = false
        probe.onUpdate = {
            guard !answered else { return }
            answered = true
            firstAnswer.fulfill()
        }

        probe.start(fragment: fragment)

        guard XCTWaiter().wait(for: [firstAnswer], timeout: 5) != .timedOut else {
            print("PROBE \(name): timeout")
            probe.stop()
            return
        }

        // The first callback is allowed to be an empty placeholder while MapKit
        // is still resolving; give it up to two more seconds so an early empty
        // answer is not recorded as "Apple returned nothing".
        if probe.results.isEmpty, probe.failure == nil {
            let nonEmpty = expectation(description: "\(name) non-empty answer")
            var settled = false
            probe.onUpdate = {
                guard !settled, !probe.results.isEmpty else { return }
                settled = true
                nonEmpty.fulfill()
            }
            _ = XCTWaiter().wait(for: [nonEmpty], timeout: 2)
        }

        print("PROBE \(name): \(extra)\(probe.line(limit: limit, titlesOnly: titlesOnly))")
        probe.stop()
    }
}

/// Minimal delegate that keeps the latest completion results and reports every
/// update through one closure, so the probe decides when to stop waiting.
private final class CompleterProbe: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []
    private(set) var failure: String?
    var onUpdate: (() -> Void)?

    private let completer = MKLocalSearchCompleter()

    init(resultTypes: MKLocalSearchCompleter.ResultType, region: MKCoordinateRegion?) {
        super.init()
        completer.delegate = self
        completer.resultTypes = resultTypes
        if let region {
            completer.region = region
        }
    }

    func start(fragment: String) {
        completer.queryFragment = fragment
    }

    func stop() {
        completer.delegate = nil
        completer.queryFragment = ""
    }

    func line(limit: Int, titlesOnly: Bool) -> String {
        if let failure {
            return "count=\(results.count) error=\(sanitized(failure))"
        }
        let entries = results.prefix(limit).map { completion -> String in
            titlesOnly
                ? sanitized(completion.title)
                : "\(sanitized(completion.title)) ‖ \(sanitized(completion.subtitle))"
        }
        return "count=\(results.count) first\(limit)=[\(entries.joined(separator: " | "))]"
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
        failure = nil
        onUpdate?()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        failure = error.localizedDescription
        onUpdate?()
    }
}

/// Keeps one `PROBE ` line one line: separators and newlines inside a place name
/// would otherwise split the line the report has to quote verbatim.
private func sanitized(_ value: String?) -> String {
    guard let value else { return "nil" }
    let separators = CharacterSet(charactersIn: "\n\r,，|‖")
    let flattened = value.unicodeScalars.map { separators.contains($0) ? " " : String($0) }.joined()
    return flattened.split(separator: " ").joined(separator: " ")
}
