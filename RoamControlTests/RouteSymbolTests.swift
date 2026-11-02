import XCTest
import UIKit
@testable import RoamControl

final class RouteSymbolTests: XCTestCase {
    func testRouteSymbolsExist() {
        for name in [RouteSymbol.library, RouteSymbol.open] {
            XCTAssertNotNil(
                UIImage(systemName: name),
                "\(name) is not a valid SF Symbol"
            )
        }
    }
}
