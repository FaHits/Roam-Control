import Foundation

struct PublishedRelease: Sendable {
    let version: String
    let name: String
    let releaseURL: URL
}

enum ReleaseUpdateStatus: Equatable {
    case idle
    case checking
    case updateAvailable(PublishedRelease)
    case current(PublishedRelease)
    case newerLocalBuild(PublishedRelease)
    case noPublishedRelease
    case unavailable
}

extension ReleaseUpdateStatus {
    static func == (lhs: ReleaseUpdateStatus, rhs: ReleaseUpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.noPublishedRelease, .noPublishedRelease), (.unavailable, .unavailable):
            true
        case let (.updateAvailable(left), .updateAvailable(right)),
             let (.current(left), .current(right)),
             let (.newerLocalBuild(left), .newerLocalBuild(right)):
            left.version == right.version && left.releaseURL == right.releaseURL
        default:
            false
        }
    }
}

struct ReleaseUpdateChecker {
    func latestRelease() async throws -> PublishedRelease {
        var request = URLRequest(url: AppRepository.latestReleaseAPIURL)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ReleaseUpdateCheckError.unavailable
        }

        return try Self.result(statusCode: response.statusCode, body: data)
    }

    /// Pure mapping from a GitHub response to a release, so every status code
    /// path is testable without a network. 404 means the repository has no
    /// published release yet; it is never filled in from the fork's upstream.
    static func result(statusCode: Int, body: Data) throws -> PublishedRelease {
        guard statusCode == 200 else {
            throw statusCode == 404
                ? ReleaseUpdateCheckError.noPublishedRelease
                : ReleaseUpdateCheckError.unavailable
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: body)
        guard let releaseURL = URL(string: release.htmlURL) else {
            throw ReleaseUpdateCheckError.unavailable
        }

        return PublishedRelease(
            version: release.tagName,
            name: release.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? release.name!
                : release.tagName,
            releaseURL: releaseURL
        )
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
        }
    }

}

enum ReleaseUpdateCheckError: Error {
    case noPublishedRelease
    case unavailable
}

enum VersionComparison {
    static func isRemoteVersionNewer(_ remoteVersion: String, than localVersion: String) -> Bool {
        let remote = components(from: remoteVersion)
        let local = components(from: localVersion)
        let length = max(remote.count, local.count)

        for index in 0..<length {
            let remoteValue = index < remote.count ? remote[index] : 0
            let localValue = index < local.count ? local[index] : 0
            if remoteValue != localValue { return remoteValue > localValue }
        }

        return remoteVersion.lowercased().contains("beta") == false
            && localVersion.lowercased().contains("beta")
    }

    private static func components(from value: String) -> [Int] {
        value
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }
}
