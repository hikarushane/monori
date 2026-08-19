import XCTest
@testable import MonoriCore

final class ReaderStylerTests: XCTestCase {
    func testInjectionScriptEmbedsRulesetAndStyleId() {
        let js = ReaderStyler.injectionScript()
        XCTAssertTrue(js.contains(ReaderStyler.styleElementID))
        XCTAssertTrue(js.contains("--monori-font-size"))
        XCTAssertTrue(js.contains("Source Serif 4"))
    }

    func testRemovalScriptTargetsSameId() {
        XCTAssertTrue(ReaderStyler.removalScript().contains(ReaderStyler.styleElementID))
    }

    func testFontSizeScriptSetsVariable() {
        let js = ReaderStyler.fontSizeScript(points: 21)
        XCTAssertTrue(js.contains("--monori-font-size"))
        XCTAssertTrue(js.contains("21px"))
    }

    func testLineHeightScriptSetsVariable() {
        let js = ReaderStyler.lineHeightScript(value: 1.9)
        XCTAssertTrue(js.contains("--monori-line-height"))
        XCTAssertTrue(js.contains("1.90"))
    }

    func testLineHeightScriptUsesCSSDecimalSeparator() {
        let js = ReaderStyler.lineHeightScript(value: 1.9)
        XCTAssertEqual(js, "document.documentElement.style.setProperty('--monori-line-height', '1.90');")
        XCTAssertFalse(js.contains("1,90"))
    }

    func testLineHeightScriptClampsRange() {
        XCTAssertTrue(ReaderStyler.lineHeightScript(value: 9.0).contains("2.40"))
        XCTAssertTrue(ReaderStyler.lineHeightScript(value: 0.1).contains("1.20"))
    }

    func testRulesetUsesLineHeightVariable() {
        XCTAssertTrue(ReaderStyler.ruleset().contains("var(--monori-line-height"))
    }

    func testEnforceScrollScriptEmbedsTargetAndUserInteractionGuard() {
        let js = ReaderStyler.enforceScrollScript(progress: 0.5)
        XCTAssertTrue(js.contains("var target = 0.5"))
        XCTAssertTrue(js.contains("__monoriUserInteracted"))
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
        XCTAssertTrue(css.contains("post-content\"] p"))
        XCTAssertTrue(css.contains("post-content\"] li"))
    }

    func testRulesetTargetsPatreonPostContentClass() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains(".patreon-post-content"))
        XCTAssertTrue(css.contains(".patreon-post-content p"))
    }

    func testRulesetHidesPromoSectionsButKeepsComments() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("PostCollectionPlaylistCard"))
        XCTAssertTrue(css.contains("launcher-post-card"))
        XCTAssertFalse(css.contains("content-card-comment-thread-container"))
        XCTAssertFalse(css.contains("comment-row"))
        XCTAssertFalse(css.contains("comment-field"))
    }

    // MARK: - Uguisu Zen typography

    func testRulesetUsesSourceSerif4() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("Source Serif 4"))
        XCTAssertTrue(css.contains("Noto Serif TC"))
        XCTAssertFalse(css.contains("Georgia"), "Georgia must not appear in Patreon ruleset")
    }

    func testRulesetDeclaresLocalFontFace() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains(#"local("SourceSerif4Variable-Roman")"#))
        XCTAssertTrue(css.contains(#"local("NotoSerifTC-Regular")"#))
    }

    func testRulesetUsesWashiWhiteBackground() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("#FBF9F8"))
        XCTAssertFalse(css.contains("#faf8f5"), "Old background color must be removed")
    }

    func testRulesetUsesSumiInkDarkBackground() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("#1C1B19"))
    }

    func testRulesetDarkModeTextColor() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("#F2F0ED"))
    }

    func testRulesetDefaultLineHeight19() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("--monori-line-height, 1.9"))
    }

    func testRulesetParagraphSpacing() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("0.85em"))
    }

    func testRulesetMaxWidth34em() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("34em"))
        XCTAssertFalse(css.contains("42em"), "Old max-width 42em must be removed")
    }

    func testRulesetHorizontalPadding() {
        let css = ReaderStyler.ruleset()
        XCTAssertTrue(css.contains("clamp(24px, 6vw, 48px)"))
    }

    // MARK: - Vocus ruleset

    func testVocusRulesetUsesSourceSerif4() {
        let css = ReaderStyler.vocusRuleset()
        XCTAssertTrue(css.contains("Source Serif 4"))
        XCTAssertTrue(css.contains("Noto Serif TC"))
        XCTAssertFalse(css.contains("Georgia"))
    }

    func testVocusRulesetDeclaresLocalFontFace() {
        let css = ReaderStyler.vocusRuleset()
        XCTAssertTrue(css.contains(#"local("SourceSerif4Variable-Roman")"#))
    }

    func testVocusRulesetUsesWashiWhite() {
        let css = ReaderStyler.vocusRuleset()
        XCTAssertTrue(css.contains("#FBF9F8"))
        XCTAssertFalse(css.contains("#faf8f5"))
    }

    func testVocusRulesetDarkTextColor() {
        let css = ReaderStyler.vocusRuleset()
        XCTAssertTrue(css.contains("#F2F0ED"))
        XCTAssertFalse(css.contains("#e8e6e3"), "Old dark text color must be removed")
    }

    func testVocusRulesetDefaultLineHeight19() {
        let css = ReaderStyler.vocusRuleset()
        XCTAssertTrue(css.contains("--monori-line-height, 1.9"))
    }

    func testVocusRulesetParagraphSpacing() {
        let css = ReaderStyler.vocusRuleset()
        XCTAssertTrue(css.contains("0.85em"))
    }

    func testVocusRulesetMaxWidth34em() {
        let css = ReaderStyler.vocusRuleset()
        XCTAssertTrue(css.contains("34em"))
        XCTAssertFalse(css.contains("42em"))
    }

    // MARK: - AFF ruleset

    func testAFFRulesetUsesSourceSerif4() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains("Source Serif 4"))
        XCTAssertTrue(css.contains("Noto Serif TC"))
        XCTAssertFalse(css.contains("Georgia"))
    }

    func testAFFRulesetDeclaresLocalFontFace() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains(#"local("SourceSerif4Variable-Roman")"#))
    }

    func testAFFRulesetUsesWashiWhite() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains("#FBF9F8"))
        XCTAssertFalse(css.contains("#faf8f5"))
    }

    func testAFFRulesetDarkTextColor() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains("#F2F0ED"))
        XCTAssertFalse(css.contains("#e8e6e3"))
    }

    func testAFFRulesetDefaultLineHeight19() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains("--monori-line-height, 1.9"))
    }

    func testAFFRulesetParagraphSpacing() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains("0.85em"))
    }

    func testAFFRulesetMaxWidth34em() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains("34em"))
        XCTAssertFalse(css.contains("42em"))
    }

    func testAFFRulesetKeepsCommentThread() {
        let css = ReaderStyler.affRuleset()
        XCTAssertTrue(css.contains("#comments"), "CSS must reference #comments")
        XCTAssertTrue(css.contains(":not(#comments)"),
                      "Comments are preserved via :not(#comments) exclusion")
        XCTAssertTrue(css.contains("section#comments"),
                      "Comment section is styled, not hidden")
    }

    // MARK: - wrappedDocument (Google Docs)

    func testWrappedDocumentEmbedsPrefsVariables() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 21, lineHeight: 1.9)
        XCTAssertTrue(html.contains("--monori-font-size: 21px"))
        XCTAssertTrue(html.contains("--monori-line-height: 1.90"))
        XCTAssertTrue(html.contains("<p>x</p>"))
    }

    func testWrappedDocumentUsesSourceSerif4() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9)
        XCTAssertTrue(html.contains("Source Serif 4"))
        XCTAssertTrue(html.contains("Noto Serif TC"))
        XCTAssertFalse(html.contains("-apple-system"), "System sans must be removed")
        XCTAssertFalse(html.contains("PingFang"), "PingFang must be removed")
        XCTAssertFalse(html.contains("Georgia"))
    }

    func testWrappedDocumentDeclaresLocalFontFace() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9)
        XCTAssertTrue(html.contains(#"local("SourceSerif4Variable-Roman")"#))
        XCTAssertTrue(html.contains(#"local("NotoSerifTC-Regular")"#))
    }

    func testWrappedDocumentUsesWashiWhite() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9)
        XCTAssertTrue(html.contains("#FBF9F8"))
    }

    func testWrappedDocumentDarkModeColors() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9)
        XCTAssertTrue(html.contains("#1C1B19"))
        XCTAssertTrue(html.contains("#F2F0ED"))
    }

    func testWrappedDocumentParagraphSpacing() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9)
        XCTAssertTrue(html.contains("0.85em"))
    }

    func testWrappedDocumentMaxWidth34em() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9)
        XCTAssertTrue(html.contains("34em"))
    }

    func testWrappedDocumentOverridesInlineStylesOnProseDescendants() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.75)
        XCTAssertTrue(html.contains("body p *"))
        XCTAssertTrue(html.contains("font-size: var(--monori-font-size) !important"))
        XCTAssertTrue(html.contains("line-height: var(--monori-line-height) !important"))
        XCTAssertFalse(html.contains("body h1"))
        XCTAssertFalse(html.contains("body span "))
    }

    func testWrappedDocumentClampsAndFormats() {
        let big = ReaderStyler.wrappedDocument(inner: "", fontSizePoints: 99, lineHeight: 9.0)
        XCTAssertTrue(big.contains("--monori-font-size: 32px"))
        XCTAssertTrue(big.contains("--monori-line-height: 2.40"))
        let small = ReaderStyler.wrappedDocument(inner: "", fontSizePoints: 1, lineHeight: 0.1)
        XCTAssertTrue(small.contains("--monori-font-size: 14px"))
        XCTAssertTrue(small.contains("--monori-line-height: 1.20"))
    }

    func testWrappedDocumentSupportsLightAndDarkScheme() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 18, lineHeight: 1.6)
        XCTAssertTrue(html.contains(#"<meta name="color-scheme" content="light dark">"#))
        XCTAssertTrue(html.contains("color-scheme: light dark"))
    }

    // MARK: - Font check in injection scripts

    func testInjectionScriptContainsFontCheck() {
        let js = ReaderStyler.injectionScript()
        XCTAssertTrue(js.contains("document.fonts.check"))
        XCTAssertTrue(js.contains("Source Serif 4"))
    }

    func testVocusInjectionScriptContainsFontCheck() {
        let js = ReaderStyler.vocusInjectionScript()
        XCTAssertTrue(js.contains("document.fonts.check"))
    }

    func testAFFInjectionScriptContainsFontCheck() {
        let js = ReaderStyler.affInjectionScript()
        XCTAssertTrue(js.contains("document.fonts.check"))
    }

    // MARK: - No banned fonts across all rulesets

    func testNoGeorgiaAcrossAllRulesets() {
        XCTAssertFalse(ReaderStyler.ruleset().contains("Georgia"))
        XCTAssertFalse(ReaderStyler.vocusRuleset().contains("Georgia"))
        XCTAssertFalse(ReaderStyler.affRuleset().contains("Georgia"))
    }

    func testNoSFProAcrossAllRulesets() {
        for css in [ReaderStyler.ruleset(), ReaderStyler.vocusRuleset(), ReaderStyler.affRuleset()] {
            XCTAssertFalse(css.contains("SF Pro"))
            XCTAssertFalse(css.contains("-apple-system"))
        }
    }
}
