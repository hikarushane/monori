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

    func testLineHeightScriptSetsVariable() {
        let js = ReaderStyler.lineHeightScript(value: 1.9)
        XCTAssertTrue(js.contains("--chapterly-line-height"))
        XCTAssertTrue(js.contains("1.90"))
    }

    func testLineHeightScriptUsesCSSDecimalSeparator() {
        let js = ReaderStyler.lineHeightScript(value: 1.9)
        XCTAssertEqual(js, "document.documentElement.style.setProperty('--chapterly-line-height', '1.90');")
        XCTAssertFalse(js.contains("1,90"))
    }

    func testLineHeightScriptClampsRange() {
        XCTAssertTrue(ReaderStyler.lineHeightScript(value: 9.0).contains("2.40"))
        XCTAssertTrue(ReaderStyler.lineHeightScript(value: 0.1).contains("1.20"))
    }

    func testRulesetUsesLineHeightVariable() {
        XCTAssertTrue(ReaderStyler.ruleset().contains("var(--chapterly-line-height"))
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

    func testRulesetSizesParagraphDescendants() {
        let css = ReaderStyler.ruleset()
        // The size/line-height rule must reach the text nodes, not just the
        // container, or Patreon's per-paragraph font-size wins (Bug 1).
        XCTAssertTrue(css.contains("post-content\"] p"))
        XCTAssertTrue(css.contains("post-content\"] li"))
    }
}
