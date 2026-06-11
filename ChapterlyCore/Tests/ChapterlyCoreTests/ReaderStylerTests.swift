import XCTest
@testable import ChapterlyCore

final class ReaderStylerTests: XCTestCase {
    func testInjectionScriptEmbedsRulesetAndStyleId() {
        let js = ReaderStyler.injectionScript()
        XCTAssertTrue(js.contains(ReaderStyler.styleElementID))
        XCTAssertTrue(js.contains("--chapterly-font-size"))
        XCTAssertTrue(js.contains("data-tag")) // ruleset content embedded
    }

    func testRemovalScriptTargetsSameId() {
        XCTAssertTrue(ReaderStyler.removalScript().contains(ReaderStyler.styleElementID))
    }

    func testFontSizeScriptSetsVariable() {
        let js = ReaderStyler.fontSizeScript(points: 21)
        XCTAssertTrue(js.contains("--chapterly-font-size"))
        XCTAssertTrue(js.contains("21px"))
    }

    func testScrollToTopScript() {
        XCTAssertEqual(ReaderStyler.scrollToTopScript(), "window.scrollTo(0, 0);")
    }

    func testRulesetEscapedForTemplateLiteral() {
        XCTAssertFalse(ReaderStyler.ruleset().contains("`"))
        XCTAssertFalse(ReaderStyler.ruleset().contains("${"))
    }
}
