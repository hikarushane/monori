import XCTest
import MonoriCore

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(MonoriCore.version, "0.1.0")
    }
}
