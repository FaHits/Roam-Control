import XCTest
import UIKit
@testable import RoamControl

final class RouteSymbolTests: XCTestCase {
    func testLibrarySymbolExists() {
        XCTAssertNotNil(
            UIImage(systemName: RouteSymbol.library),
            "\(RouteSymbol.library) is not a valid SF Symbol"
        )
    }
}
