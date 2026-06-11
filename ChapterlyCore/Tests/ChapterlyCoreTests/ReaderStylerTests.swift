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

    func testEnforceScrollScriptEmbedsTargetAndUserInteractionGuard() {
        let js = ReaderStyler.enforceScrollScript(progress: 0.5)
        XCTAssertTrue(js.contains("var target = 0.5"))
        XCTAssertTrue(js.contains("__chapterlyUserInteracted"))
        XCTAssertTrue(js.contains("setInterval"))
    }

    func testEnforceScrollScriptDefaultsToTopWhenNil() {
        let js = ReaderStyler.enforceScrollScript(progress: nil)
        XCTAssertTrue(js.contains("var target = 0.0"))
    }

    func testEnforceScrollScriptClampsOutOfRangeProgress() {
        XCTAssertTrue(ReaderStyler.enforceScrollScript(progress: 1.7).contains("var target = 1.0"))
        XCTAssertTrue(ReaderStyler.enforceScrollScript(progress: -0.3).contains("var target = 0.0"))
    }

    func testRulesetEscapedForTemplateLiteral() {
        XCTAssertFalse(ReaderStyler.ruleset().contains("`"))
        XCTAssertFalse(ReaderStyler.ruleset().contains("${"))
    }
}
