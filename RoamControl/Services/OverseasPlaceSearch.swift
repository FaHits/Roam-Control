import Foundation

/// One place returned by the OpenStreetMap geocoder.
struct OverseasPlace: Equatable, Sendable {
    /// The place's own name, for example 东京国际机场.
    let name: String
    /// The address below the name, for example 羽田空港, 大田区, 东京都/東京都, 144-0041, 日本.
    let detail: String
    let latitude: Double
    let longitude: Double
}

enum OverseasPlaceSearchError: Error, Equatable {
    case badStatus(Int)
    case network
}

/// Overseas place search through Nominatim.
///
/// Apple's geocoder resolves an overseas query inside the storefront's own data
/// set, so on a mainland China network with a CN Apple ID "Tokyo haneda airport"
/// comes back as a pool shop in Zhanjiang no matter which region or retry the
/// app uses. Nominatim answers the same query with the airport, so the setting
/// swaps the source instead of tuning MapKit.
struct OverseasPlaceSearch: Sendable {
    /// Default implementation hits `nominatim.openstreetmap.org`; tests inject a
    /// stand-in and never touch the network.
    var perform: @Sendable (String, String) async throws -> [OverseasPlace]

    static let live = OverseasPlaceSearch { query, language in
        try await OverseasPlaceSearch.fetch(query: query, language: language)
    }

    static let endpointHost = "nominatim.openstreetmap.org"

    /// The public instance rejects an anonymous client, so the app identifies itself.
    static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "RoamControl/\(version) (+https://github.com/FaHits/Roam-Control)"
    }

    static func request(query: String, language: String) -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpointHost
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "limit", value: "8"),
            URLQueryItem(name: "addressdetails", value: "0"),
            URLQueryItem(name: "accept-language", value: language)
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static func fetch(query: String, language: String) async throws -> [OverseasPlace] {
        guard let request = request(query: query, language: language) else {
            throw OverseasPlaceSearchError.network
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            // A cancelled task must read as cancellation, not as "the network is down".
            if error.code == .cancelled { throw CancellationError() }
            throw OverseasPlaceSearchError.network
        } catch {
            throw OverseasPlaceSearchError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw OverseasPlaceSearchError.network
        }
        guard http.statusCode == 200 else {
            throw OverseasPlaceSearchError.badStatus(http.statusCode)
        }

        return parse(data)
    }

    /// Keeps the server's order, drops a row whose coordinates will not parse.
    static func parse(_ data: Data) -> [OverseasPlace] {
        guard let results = try? JSONDecoder().decode([NominatimResult].self, from: data) else {
            return []
        }
        return results.compactMap(place(from:))
    }

    private static func place(from result: NominatimResult) -> OverseasPlace? {
        guard
            let latitude = Double(result.lat.trimmingCharacters(in: .whitespacesAndNewlines)),
            let longitude = Double(result.lon.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }

        let segments = result.displayName
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let declaredName = result.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = declaredName.isEmpty
            ? (segments.first ?? result.displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            : declaredName

        var detail = segments
        if let first = detail.first,
           first.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            detail.removeFirst()
        }

        return OverseasPlace(
            name: name,
            detail: detail.joined(separator: ", "),
            latitude: latitude,
            longitude: longitude
        )
    }

    private struct NominatimResult: Decodable {
        let displayName: String
        let name: String?
        let lat: String
        let lon: String

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case name
            case lat
            case lon
        }
    }
}
