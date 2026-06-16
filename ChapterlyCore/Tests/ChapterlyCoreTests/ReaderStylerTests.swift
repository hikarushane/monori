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

    func testRulesetTargetsPatreonPostContentClass() {
        let css = ReaderStyler.ruleset()
        // Patreon's post-detail page dropped data-tag="post-content"/<article>
        // (Task 2 probe, 2026-06); the live container is now .patreon-post-content.
        // Pin this selector so a future accidental revert is caught by `swift test`
        // instead of silently shipping a reader where typography never applies.
        XCTAssertTrue(css.contains(".patreon-post-content"))
        XCTAssertTrue(css.contains(".patreon-post-content p"))
    }

    func testRulesetHidesPromoSectionsButKeepsComments() {
        let css = ReaderStyler.ruleset()
        // Real Patreon tokens captured from the live logged-in reader (Opt1).
        // "From the collection" carousel:
        XCTAssertTrue(css.contains("PostCollectionPlaylistCard"))
        // "Related posts" cards (Patreon exposes no section data-tag; the cards
        // themselves carry launcher-post-card):
        XCTAssertTrue(css.contains("launcher-post-card"))
        // The comment thread must stay visible — never hidden.
        XCTAssertFalse(css.contains("content-card-comment-thread-container"))
        // The thread must be fully readable: the reader ruleset must not hide
        // individual comments or the reply field, or "Load more comments" loads
        // rows that are display:none and looks like it failed.
        XCTAssertFalse(css.contains("comment-row"))
        XCTAssertFalse(css.contains("comment-field"))
    }
}
