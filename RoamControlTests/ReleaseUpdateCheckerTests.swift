import XCTest
@testable import RoamControl

final class ReleaseUpdateCheckerTests: XCTestCase {
    private func queryItems(of url: URL) -> [String: String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            items[item.name] = item.value
        }
        return items
    }

    private func releaseBody(tag: String, name: String?) -> Data {
        var json = """
        {"tag_name": "\(tag)", "html_url": "https://github.com/FaHits/Roam-Control/releases/tag/\(tag)"
        """
        if let name {
            json += ", \"name\": \"\(name)\""
        } else {
            json += ", \"name\": null"
        }
        json += "}"
        return Data(json.utf8)
    }

    // MARK: - AppRepository

    func testIssueURLsPointAtForkRepositoryWithTemplate() {
        let bug = AppRepository.issuesURL(template: "bug_report.yml")
        XCTAssertEqual(bug.host, "github.com")
        XCTAssertEqual(bug.path, "/FaHits/Roam-Control/issues/new")
        XCTAssertEqual(queryItems(of: bug)["template"], "bug_report.yml")

        let feature = AppRepository.issuesURL(template: "feature_request.yml")
        XCTAssertEqual(feature.host, "github.com")
        XCTAssertEqual(feature.path, "/FaHits/Roam-Control/issues/new")
        XCTAssertEqual(queryItems(of: feature)["template"], "feature_request.yml")
    }

    func testLatestReleaseAPIURLPointsAtForkRepository() {
        XCTAssertEqual(
            AppRepository.latestReleaseAPIURL.absoluteString,
            "https://api.github.com/repos/FaHits/Roam-Control/releases/latest"
        )
    }

    // MARK: - Status mapping

    func testResultDecodesPublishedRelease() throws {
        let release = try ReleaseUpdateChecker.result(
            statusCode: 200,
            body: releaseBody(tag: "v0.10.0", name: "Manual running routes")
        )

        XCTAssertEqual(release.version, "v0.10.0")
        XCTAssertEqual(release.name, "Manual running routes")
        XCTAssertEqual(
            release.releaseURL.absoluteString,
            "https://github.com/FaHits/Roam-Control/releases/tag/v0.10.0"
        )
    }

    func testResultFallsBackToTagWhenNameIsBlank() throws {
        let release = try ReleaseUpdateChecker.result(
            statusCode: 200,
            body: releaseBody(tag: "v0.10.0", name: "   ")
        )

        XCTAssertEqual(release.version, "v0.10.0")
        XCTAssertEqual(release.name, "v0.10.0")
    }

    func testResultMaps404ToNoPublishedRelease() {
        XCTAssertThrowsError(try ReleaseUpdateChecker.result(statusCode: 404, body: Data("{}".utf8))) { error in
            guard case ReleaseUpdateCheckError.noPublishedRelease = error else {
                return XCTFail("Expected noPublishedRelease, got \(error)")
            }
        }
    }

    func testResultMapsOtherStatusCodesToUnavailable() {
        for statusCode in [500, 403, 200] where statusCode != 200 {
            XCTAssertThrowsError(try ReleaseUpdateChecker.result(statusCode: statusCode, body: Data("{}".utf8))) { error in
                guard case ReleaseUpdateCheckError.unavailable = error else {
                    return XCTFail("Expected unavailable for \(statusCode), got \(error)")
                }
            }
        }
    }
}
