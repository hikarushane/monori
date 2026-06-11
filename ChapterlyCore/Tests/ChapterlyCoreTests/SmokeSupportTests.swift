import XCTest
@testable import ChapterlyCore

final class SmokeSupportTests: XCTestCase {

    // MARK: SmokeCheck

    func testApproximatelyEqualWithinTolerance() {
        XCTAssertTrue(SmokeCheck.approximatelyEqual(0.5, 0.55, tolerance: 0.1))
        XCTAssertTrue(SmokeCheck.approximatelyEqual(0.55, 0.5, tolerance: 0.1))
        XCTAssertTrue(SmokeCheck.approximatelyEqual(0.5, 0.6, tolerance: 0.1))
    }

    func testApproximatelyEqualOutsideTolerance() {
        XCTAssertFalse(SmokeCheck.approximatelyEqual(0.5, 0.61, tolerance: 0.1))
        XCTAssertFalse(SmokeCheck.approximatelyEqual(0.2, 0.5, tolerance: 0.1))
    }

    // MARK: SmokeReport

    func testStepLinePass() {
        XCTAssertEqual(SmokeReport.stepLine(step: "import", pass: true, reason: nil),
                       "step=import result=pass")
    }

    func testStepLineFailWithReason() {
        XCTAssertEqual(SmokeReport.stepLine(step: "auth", pass: false, reason: "not_logged_in"),
                       "step=auth result=fail reason=not_logged_in")
    }

    func testStepLinePassIgnoresReason() {
        XCTAssertEqual(SmokeReport.stepLine(step: "import", pass: true, reason: "ignored"),
                       "step=import result=pass")
    }

    func testStepLineReasonWhitespaceIsSanitized() {
        XCTAssertEqual(SmokeReport.stepLine(step: "x", pass: false, reason: "two words"),
                       "step=x result=fail reason=two_words")
    }
}
