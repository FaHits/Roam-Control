import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class MapViewModel: NSObject, MKLocalSearchCompleterDelegate {
    var searchQuery = ""
    var searchSuggestions: [MapSearchSuggestion] = []
    var selectedLocation: LocationTarget?
    var isSearching = false
    var isFindingRealLocation = false
    var errorMessage: String?
    var cameraPosition: MapCameraPosition
    /// Only changes how a query is normalized and whether the subtitle shows a
    /// country or region name. It no longer biases the search by viewport: a map
    /// parked on Zhanjiang must still resolve "Tokyo haneda airport".
    var overseasPlaceSearchEnabled = false {
        didSet {
            guard oldValue != overseasPlaceSearchEnabled else { return }
            cancelOverseasSearch()
            searchSuggestions = []
            searchCompleter.queryFragment = ""
        }
    }

    /// The only source of overseas suggestions while the toggle is on.
    /// Replaceable so a test never leaves the device.
    @ObservationIgnored
    var overseasSearch = OverseasPlaceSearch.live

    @ObservationIgnored
    private let searchCompleter = MKLocalSearchCompleter()
    @ObservationIgnored
    private var overseasSearchTask: Task<Void, Never>?
    @ObservationIgnored
    private var lastOverseasRequestAt: Date?
    @ObservationIgnored
    private let locationManager = CLLocationManager()
    @ObservationIgnored
    private var recenterOnNextRealLocation = false
    @ObservationIgnored
    private var locationRequestStartedAt: Date?
    @ObservationIgnored
    private var locationTimeout: Task<Void, Never>?
    @ObservationIgnored
    private var shouldReportLocationErrors = false
    @ObservationIgnored
    private var lastRealLocation: CLLocation?
    @ObservationIgnored
    private var isRealLocationCacheTrusted = true
    @ObservationIgnored
    private var requiresFreshRealLocation = false

    override init() {
        cameraPosition = .automatic
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest, .query]
        // Leaving `region` untouched is what keeps the completer unbiased: a world
        // span is not neutral, because MapKit anchors it on its centre and that
        // collapsed overseas suggestions to an empty list.
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        if AppModel.isUITestRun {
            // The fixture run has no network; a typed query must not reach the geocoder.
            overseasSearch = OverseasPlaceSearch { _, _ in [] }
        }
    }

    var isShowingSuggestions: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !searchSuggestions.isEmpty
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        errorMessage = nil

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch coordinateInput(from: trimmedQuery) {
        case .coordinate, .invalid:
            cancelOverseasSearch()
            searchSuggestions = []
            searchCompleter.queryFragment = ""
            return
        case .notCoordinates:
            break
        }

        if overseasPlaceSearchEnabled {
            // The completer cannot answer an overseas query from the CN data set,
            // and mixing its suggestions with the geocoder's would ship two sources
            // into one list, so it stays empty while the toggle is on.
            searchCompleter.queryFragment = ""
            guard trimmedQuery.count >= 3 else {
                cancelOverseasSearch()
                searchSuggestions = []
                return
            }
            requestOverseasSuggestions(for: trimmedQuery)
            return
        }

        cancelOverseasSearch()

        guard trimmedQuery.count >= 2 else {
            searchSuggestions = []
            searchCompleter.queryFragment = ""
            return
        }

        searchCompleter.queryFragment = trimmedQuery
    }

    /// Debounces one query, then replaces whatever request was in flight.
    private func requestOverseasSuggestions(for query: String) {
        overseasSearchTask?.cancel()
        overseasSearchTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            await self?.fetchOverseasSuggestions(for: query)
        }
    }

    private func fetchOverseasSuggestions(for query: String) async {
        if let lastOverseasRequestAt {
            let elapsed = Date().timeIntervalSince(lastOverseasRequestAt)
            if elapsed < 1 {
                do {
                    try await Task.sleep(for: .seconds(1 - elapsed))
                } catch {
                    return
                }
            }
        }
        guard !Task.isCancelled else { return }

        lastOverseasRequestAt = Date()

        let places: [OverseasPlace]
        do {
            places = try await overseasSearch.perform(query, Self.overseasLanguage)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled,
                  searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query
            else { return }
            searchSuggestions = []
            return
        }

        // The field may have moved on while the request was in flight.
        guard !Task.isCancelled,
              searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query
        else { return }

        searchSuggestions = places.map {
            MapSearchSuggestion(
                title: $0.name,
                subtitle: $0.detail,
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            )
        }
    }

    private func cancelOverseasSearch() {
        overseasSearchTask?.cancel()
        overseasSearchTask = nil
    }

    /// The language the app is displaying, as the geocoder spells it.
    private static var overseasLanguage: String {
        switch AppLanguage.displayed() {
        case .simplifiedChinese:
            return "zh-Hans"
        case .english, .system:
            return "en"
        }
    }

    func selectDroppedPin(at coordinate: CLLocationCoordinate2D) async {
        await selectCoordinate(
            coordinate,
            fallbackName: "Dropped Pin",
            fallbackDescription: "Selected from the map",
            recenter: false
        )
    }

    func search() async {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        switch coordinateInput(from: trimmedQuery) {
        case .coordinate(let coordinate):
            isSearching = true
            errorMessage = nil
            resetSearchField()
            await selectCoordinate(
                coordinate,
                fallbackName: "Entered Location",
                fallbackDescription: "Entered using coordinates",
                recenter: true
            )
            isSearching = false
            return
        case .invalid:
            searchSuggestions = []
            errorMessage = String(localized: "Enter latitude from −90 to 90 and longitude from −180 to 180.")
            return
        case .notCoordinates:
            break
        }

        if overseasPlaceSearchEnabled {
            await performOverseasSearch(for: trimmedQuery)
            return
        }

        await performSearch(for: trimmedQuery)
    }

    func selectSuggestion(_ suggestion: MapSearchSuggestion) async {
        searchQuery = suggestion.title
        searchSuggestions = []
        cancelOverseasSearch()

        if let coordinate = suggestion.coordinate {
            // The suggestion already carries its point. Searching again would
            // resolve the name against Apple's data set and land somewhere else.
            show(
                LocationTarget(
                    name: suggestion.title,
                    subtitle: suggestion.subtitle,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
            return
        }

        let query = overseasPlaceSearchEnabled
            ? suggestion.title
            : [suggestion.title, suggestion.subtitle]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        await performSearch(for: query)
    }

    /// The OpenStreetMap geocoder answers first; MapKit stays as the fallback so a blocked or
    /// empty response still ends in a readable message instead of a dead end.
    private func performOverseasSearch(for query: String) async {
        isSearching = true
        errorMessage = nil
        searchSuggestions = []
        defer { isSearching = false }

        var failed = false
        do {
            if let place = try await overseasSearch.perform(query, Self.overseasLanguage).first {
                show(
                    LocationTarget(
                        name: place.name,
                        subtitle: place.detail,
                        latitude: place.latitude,
                        longitude: place.longitude
                    )
                )
                return
            }
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }

        await performSearch(for: query)
        guard selectedLocation == nil else { return }
        errorMessage = failed
            ? String(localized: "Overseas search is unavailable right now. Check the connection and try again.")
            : String(localized: "No overseas place found for this search.")
    }

    func show(_ target: LocationTarget) {
        selectedLocation = target
        resetSearchField()
        errorMessage = nil
        center(on: target)
    }

    func center(on target: LocationTarget) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: target.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        )
    }

    func show(_ route: MKRoute) {
        let routeRect = route.polyline.boundingMapRect
        guard !routeRect.isNull, !routeRect.isEmpty else { return }

        let horizontalPadding = max(routeRect.size.width * 0.24, 1_200)
        let verticalPadding = max(routeRect.size.height * 0.30, 1_200)
        cameraPosition = .rect(
            routeRect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
        )
    }

    /// Frames a manual route: its bounding box plus 25% padding on every side, with a minimum span
    /// so a short route still reads as a place rather than a pixel.
    func show(_ geometry: RouteGeometry) {
        let coordinates = geometry.points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        guard let first = coordinates.first else {
            cameraPosition = .automatic
            return
        }

        var minimumLatitude = first.latitude
        var maximumLatitude = first.latitude
        var minimumLongitude = first.longitude
        var maximumLongitude = first.longitude

        for coordinate in coordinates.dropFirst() {
            minimumLatitude = min(minimumLatitude, coordinate.latitude)
            maximumLatitude = max(maximumLatitude, coordinate.latitude)
            minimumLongitude = min(minimumLongitude, coordinate.longitude)
            maximumLongitude = max(maximumLongitude, coordinate.longitude)
        }

        let centre = CLLocationCoordinate2D(
            latitude: (minimumLatitude + maximumLatitude) / 2,
            longitude: (minimumLongitude + maximumLongitude) / 2
        )
        let minimumSpan = 0.002
        let latitudeDelta = max((maximumLatitude - minimumLatitude) * 1.5, minimumSpan)
        let longitudeDelta = max((maximumLongitude - minimumLongitude) * 1.5, minimumSpan)
        guard centre.latitude.isFinite,
              centre.longitude.isFinite,
              latitudeDelta.isFinite,
              longitudeDelta.isFinite else {
            cameraPosition = .automatic
            return
        }

        cameraPosition = .region(
            MKCoordinateRegion(
                center: centre,
                span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            )
        )
    }

    func prepareCurrentLocation(recenter: Bool = false) {
        requestCurrentLocation(
            recenter: recenter,
            reportErrors: false,
            requireFreshLocation: false
        )
    }

    func showRealLocationAfterSession() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            self?.refreshRealLocationAfterRestoration()
        }
    }

    func refreshRealLocationAfterRestoration() {
        requestCurrentLocation(
            recenter: true,
            reportErrors: true,
            requireFreshLocation: true
        )
    }

    func showCurrentLocation() {
        if let cachedLocation = cachedRealLocation() {
            center(on: cachedLocation)
            errorMessage = nil
            isFindingRealLocation = false
            requestCurrentLocation(
                recenter: false,
                reportErrors: false,
                requireFreshLocation: false
            )
            return
        }

        requestCurrentLocation(
            recenter: true,
            reportErrors: true,
            requireFreshLocation: !isRealLocationCacheTrusted
        )
    }

    func invalidateRealLocationCache() {
        lastRealLocation = nil
        isRealLocationCacheTrusted = false
    }

    private func performSearch(for query: String) async {
        isSearching = true
        errorMessage = nil
        searchSuggestions = []
        defer { isSearching = false }

        do {
            // Each attempt is a full search; the first hit wins and the whole query
            // always goes first.
            var item: MKMapItem?
            for attempt in MapSearchQuery.attempts(query, overseas: overseasPlaceSearchEnabled) {
                item = try await firstMapItem(for: attempt)
                if item != nil { break }
            }
            guard let item else {
                errorMessage = overseasPlaceSearchEnabled
                    ? String(localized: "No matching place found.")
                    : String(localized: "No matching place found. If this is an overseas place, turn on Search places outside China in Settings.")
                return
            }

            let coordinate = item.location.coordinate
            let target = LocationTarget(
                name: item.name ?? searchQuery,
                subtitle: placeDescription(for: item),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            selectedLocation = target
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                )
            )
            resetSearchField()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(localized: "Search is unavailable right now.")
        }
    }

    private func firstMapItem(for query: String) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        return try await MKLocalSearch(request: request).start().mapItems.first
    }

    private func selectCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        fallbackName: String,
        fallbackDescription: String,
        recenter: Bool
    ) async {
        errorMessage = nil
        let pendingTarget = LocationTarget(
            name: fallbackName,
            subtitle: "Finding nearby address…",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        selectedLocation = pendingTarget

        if recenter {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                )
            )
        }

        guard let request = MKReverseGeocodingRequest(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ) else {
            selectedLocation = LocationTarget(
                name: fallbackName,
                subtitle: fallbackDescription,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            return
        }

        do {
            let items = try await request.mapItems
            guard selectedLocation?.id == pendingTarget.id, let item = items.first else { return }

            selectedLocation = LocationTarget(
                name: item.name ?? fallbackName,
                subtitle: placeDescription(for: item),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        } catch {
            guard selectedLocation?.id == pendingTarget.id else { return }
            selectedLocation = LocationTarget(
                name: fallbackName,
                subtitle: fallbackDescription,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    private func coordinateInput(from query: String) -> CoordinateInput {
        let trimmed = query.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "()[]"))
        )
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return .notCoordinates }

        let latitudeText = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let longitudeText = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let latitude = Double(latitudeText),
            let longitude = Double(longitudeText)
        else { return .notCoordinates }

        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            return .invalid
        }

        return .coordinate(
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }

    func clearSearch() {
        resetSearchField()
        errorMessage = nil
    }

    func clearSelectedLocation() {
        selectedLocation = nil
        errorMessage = nil
    }

    private func resetSearchField() {
        searchQuery = ""
        searchSuggestions = []
        searchCompleter.queryFragment = ""
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.prefix(6).map {
            MapSearchSuggestion(title: $0.title, subtitle: $0.subtitle)
        }

        Task { @MainActor [weak self] in
            // The completer cannot answer an overseas query; a late callback from
            // the cleared fragment must not overwrite the geocoder's list.
            guard let self, !self.overseasPlaceSearchEnabled else { return }
            self.searchSuggestions = suggestions
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        Task { @MainActor [weak self] in
            guard let self, !self.overseasPlaceSearchEnabled else { return }
            self.searchSuggestions = []
        }
    }

    private func placeDescription(for item: MKMapItem) -> String {
        let invisibleCharacters = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        )
        let candidates = [
            item.address?.shortAddress,
            item.addressRepresentations?.cityWithContext,
            item.address?.fullAddress
        ]

        var detail = "Location details unavailable"
        for candidate in candidates {
            let value = candidate?.trimmingCharacters(in: invisibleCharacters) ?? ""
            if !value.isEmpty {
                detail = value
                break
            }
        }

        guard overseasPlaceSearchEnabled else { return detail }

        let region = item.addressRepresentations?.regionName ?? item.placemark.country
        guard
            let region,
            !region.isEmpty,
            !detail.localizedCaseInsensitiveContains(region)
        else { return detail }
        return "\(detail), \(region)"
    }

    private func requestCurrentLocation(
        recenter: Bool,
        reportErrors: Bool,
        requireFreshLocation: Bool
    ) {
        shouldReportLocationErrors = reportErrors
        requiresFreshRealLocation = requireFreshLocation
        switch locationManager.authorizationStatus {
        case .notDetermined:
            recenterOnNextRealLocation = recenter
            isFindingRealLocation = recenter
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            recenterOnNextRealLocation = recenter
            isFindingRealLocation = recenter
            locationRequestStartedAt = Date()
            locationManager.startUpdatingLocation()
            locationTimeout?.cancel()
            locationTimeout = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    return
                }

                guard let self, self.locationRequestStartedAt != nil else { return }
                // A simulated-location session can take a little longer than a
                // normal location request to hand control back to Core Location.
                // Do not turn a delayed, fresh callback into an error after the
                // session itself has already ended.
                self.isFindingRealLocation = false
                self.errorMessage = nil

                do {
                    try await Task.sleep(for: .seconds(45))
                } catch {
                    return
                }

                guard self.locationRequestStartedAt != nil else { return }
                self.locationManager.stopUpdatingLocation()
                self.locationRequestStartedAt = nil
                self.recenterOnNextRealLocation = false
                self.requiresFreshRealLocation = false
            }
        case .denied, .restricted:
            isFindingRealLocation = false
            if recenter && shouldReportLocationErrors {
                errorMessage = "Allow Location access in Settings to show your real position."
            }
        @unknown default:
            break
        }
    }

    private func receiveLocations(_ locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        if requiresFreshRealLocation,
           let locationRequestStartedAt,
           location.timestamp < locationRequestStartedAt.addingTimeInterval(-0.5) {
            return
        }

        lastRealLocation = location
        isRealLocationCacheTrusted = true
        requiresFreshRealLocation = false
        locationManager.stopUpdatingLocation()
        locationTimeout?.cancel()
        locationTimeout = nil
        self.locationRequestStartedAt = nil
        isFindingRealLocation = false

        guard recenterOnNextRealLocation else { return }
        recenterOnNextRealLocation = false
        errorMessage = nil
        center(on: location)
    }

    private func center(on location: CLLocation) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        )
    }

    private func cachedRealLocation() -> CLLocation? {
        guard isRealLocationCacheTrusted else { return nil }

        let candidates = [lastRealLocation, locationManager.location]
            .compactMap { $0 }
            .filter {
                $0.horizontalAccuracy >= 0
                    && $0.horizontalAccuracy <= 1_000
                    && Date().timeIntervalSince($0.timestamp) <= 300
            }

        return candidates.max { $0.timestamp < $1.timestamp }
    }
}

private enum CoordinateInput {
    case notCoordinates
    case invalid
    case coordinate(CLLocationCoordinate2D)
}

extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                requestCurrentLocation(
                    recenter: recenterOnNextRealLocation,
                    reportErrors: shouldReportLocationErrors,
                    requireFreshLocation: requiresFreshRealLocation
                )
            case .denied, .restricted:
                isFindingRealLocation = false
                if recenterOnNextRealLocation {
                    recenterOnNextRealLocation = false
                    if shouldReportLocationErrors {
                        errorMessage = "Allow Location access in Settings to show your real position."
                    }
                }
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            receiveLocations(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            let locationError = error as NSError
            if locationError.domain == kCLErrorDomain,
               locationError.code == CLError.Code.locationUnknown.rawValue {
                return
            }

            locationManager.stopUpdatingLocation()
            locationTimeout?.cancel()
            locationTimeout = nil
            locationRequestStartedAt = nil
            isFindingRealLocation = false
            if recenterOnNextRealLocation {
                recenterOnNextRealLocation = false
                if shouldReportLocationErrors {
                    errorMessage = "Your real location is not available yet."
                }
            }
        }
    }
}

struct MapSearchSuggestion: Identifiable, Sendable {
    let title: String
    let subtitle: String
    /// Set only for an OpenStreetMap result; a completer suggestion has no point yet.
    var coordinate: CLLocationCoordinate2D? = nil

    var id: String {
        "\(title)|\(subtitle)"
    }
}
