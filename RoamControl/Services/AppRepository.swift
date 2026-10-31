import Foundation

/// The single source of truth for the repository the app points users at.
/// Every user-facing GitHub URL is derived from these constants so no call
/// site can drift back to the fork's upstream.
enum AppRepository {
    static let owner = "FaHits"
    static let repo = "Roam-Control"

    static var webURL: URL {
        URL(string: "https://github.com/\(owner)/\(repo)")!
    }

    static var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }

    /// `https://github.com/<owner>/<repo>/issues/new?template=<template>`
    static func issuesURL(template: String) -> URL {
        var components = URLComponents(url: webURL.appending(path: "issues/new"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "template", value: template)]
        return components.url!
    }
}
