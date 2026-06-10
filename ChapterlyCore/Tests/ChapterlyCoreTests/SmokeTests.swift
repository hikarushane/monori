import XCTest
import ChapterlyCore

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(ChapterlyCore.version, "0.1.0")
    }
}
