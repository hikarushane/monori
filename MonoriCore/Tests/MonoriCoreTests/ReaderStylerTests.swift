import XCTest
@testable import MonoriCore
#if canImport(WebKit)
import WebKit
#endif

final class ReaderStylerTests: XCTestCase {
#if canImport(WebKit)
    @MainActor
    func testIPadReaderLayoutUsesFullWidthAndIsolatesPatreonContent() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
        webView.loadHTMLString("""
        <!doctype html><html><body>
          <header id="site-header">Patreon navigation</header>
          <main style="max-width: 760px; margin: 0 auto">
            <article style="max-width: 680px; margin: 0 auto">
              <section id="byline">Creator and date</section>
              <div id="post-actions">Like, share, more</div>
              <div id="chapter" class="patreon-post-content"><p id="paragraph">Chapter text</p></div>
              <section id="comments" data-tag="content-card-comment-thread-container">Comments</section>
            </article>
            <aside id="collection-panel">Collection chapters</aside>
          </main>
        </body></html>
        """, baseURL: URL(string: "https://www.patreon.com/posts/chapter-1"))
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        _ = try await webView.evaluateJavaScript(ReaderStyler.injectionScript())
        _ = try await webView.evaluateJavaScript(ReaderStyler.iPadReaderLayoutScript())
        let result = try await webView.evaluateJavaScript("""
        (function () {
          var chapterStyle = getComputedStyle(document.getElementById('chapter'));
          return [
            chapterStyle.maxWidth,
            chapterStyle.paddingLeft,
            getComputedStyle(document.getElementById('site-header')).display,
            getComputedStyle(document.getElementById('byline')).display,
            getComputedStyle(document.getElementById('post-actions')).display,
            getComputedStyle(document.getElementById('collection-panel')).display,
            getComputedStyle(document.getElementById('chapter')).display,
            getComputedStyle(document.getElementById('comments')).display
          ];
        })();
        """)
        let values = try XCTUnwrap(result as? [String])

        XCTAssertEqual(values[0], "none")
        XCTAssertEqual(values[1], "32px")
        XCTAssertEqual(Array(values[2...5]), Array(repeating: "none", count: 4))
        XCTAssertNotEqual(values[6], "none", "chapter content must remain visible")
        XCTAssertNotEqual(values[7], "none", "comments must remain visible")
        let chapterWidth = try await webView.evaluateJavaScript(
            "document.getElementById('chapter').getBoundingClientRect().width")
        XCTAssertGreaterThan(try XCTUnwrap(chapterWidth as? NSNumber).doubleValue, 900,
                             "Patreon ancestor containers must not keep the iPad reader narrow")
        let paragraphFont = try await webView.evaluateJavaScript(
            "getComputedStyle(document.getElementById('paragraph')).fontFamily")
        XCTAssertTrue(try XCTUnwrap(paragraphFont as? String).contains("Source Serif 4"),
                      "Patreon descendants must keep Monori's reader typography")
        let commentsPadding = try await webView.evaluateJavaScript(
            "getComputedStyle(document.getElementById('comments')).paddingLeft")
        XCTAssertEqual(commentsPadding as? String, "32px")
    }

    @MainActor
    func testIPadReaderLayoutExpandsStoredDocumentBody() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
        let html = ReaderStyler.wrappedDocument(
            inner: "<p>Stored chapter text</p>", fontSizePoints: 19, lineHeight: 1.9)
        webView.loadHTMLString(html, baseURL: URL(string: "https://docs.google.com/document/d/example"))
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        _ = try await webView.evaluateJavaScript(ReaderStyler.iPadReaderLayoutScript())
        let result = try await webView.evaluateJavaScript("""
        (function () {
          var style = getComputedStyle(document.body);
          return [style.maxWidth, style.paddingLeft, style.boxSizing];
        })();
        """)
        let values = try XCTUnwrap(result as? [String])

        XCTAssertEqual(values, ["none", "32px", "border-box"])
    }

    @MainActor
    func testIPadReaderLayoutExpandsAFFContentAncestors() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
        webView.loadHTMLString("""
        <!doctype html><html><body>
          <main style="max-width: 680px; margin: 0 auto">
            <section id="bodyText">
              <div id="content-column" style="max-width: 680px; margin: 0 auto">
                <p id="prose" style="max-width: 680px; margin: 0 auto">Chapter text</p>
              </div>
            </section>
            <section id="comments">Comments</section>
          </main>
        </body></html>
        """, baseURL: URL(string: "https://www.asianfanfics.com/story/view/1/1"))
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        _ = try await webView.evaluateJavaScript(ReaderStyler.iPadReaderLayoutScript())
        let width = try await webView.evaluateJavaScript(
            "document.getElementById('prose').getBoundingClientRect().width")

        XCTAssertGreaterThan(try XCTUnwrap(width as? NSNumber).doubleValue, 900,
                             "source-specific content ancestors must not retain phone widths")
    }
#endif

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

    // MARK: - CSS variable --monori-font-family

    func testAllRulesetsUseFontFamilyVariable() {
        for css in [ReaderStyler.ruleset(), ReaderStyler.vocusRuleset(), ReaderStyler.affRuleset()] {
            XCTAssertTrue(css.contains("--monori-font-family"),
                          "Ruleset must declare --monori-font-family")
            XCTAssertTrue(css.contains("var(--monori-font-family)"),
                          "Ruleset must use var(--monori-font-family) for font-family")
        }
    }

    func testAllRulesetsDeclareFontFamilyDefault() {
        for css in [ReaderStyler.ruleset(), ReaderStyler.vocusRuleset(), ReaderStyler.affRuleset()] {
            XCTAssertTrue(css.contains(#"--monori-font-family: "Source Serif 4", "Noto Serif TC", serif"#),
                          "Ruleset must set default --monori-font-family value")
        }
    }

    // MARK: - fontFamilyScript

    func testFontFamilyScriptBuiltInRestoresDefaultStack() {
        let js = ReaderStyler.fontFamilyScript(font: .builtIn)
        XCTAssertTrue(js.contains("Source Serif 4"))
        XCTAssertTrue(js.contains("Noto Serif TC"))
        XCTAssertTrue(js.contains("--monori-font-family"))
        XCTAssertTrue(js.contains(ReaderStyler.userFontStyleID))
    }

    func testFontFamilyScriptImportedCreatesMonoriUserFont() {
        let js = ReaderStyler.fontFamilyScript(
            font: .embeddedDataURL(mimeType: "font/ttf", base64: "AAAA"))
        XCTAssertTrue(js.contains("MonoriUserFont"))
        XCTAssertTrue(js.contains("@font-face"))
        XCTAssertTrue(js.contains("data:font/ttf;base64,AAAA"))
        XCTAssertTrue(js.contains("--monori-font-family"))
        XCTAssertTrue(js.contains("Noto Serif TC"),
                      "Imported font must keep Noto Serif TC fallback")
    }

    func testFontFamilyScriptTTFMime() {
        let js = ReaderStyler.fontFamilyScript(
            font: .embeddedDataURL(mimeType: "font/ttf", base64: "X"))
        XCTAssertTrue(js.contains("font/ttf"))
    }

    func testFontFamilyScriptOTFMime() {
        let js = ReaderStyler.fontFamilyScript(
            font: .embeddedDataURL(mimeType: "font/otf", base64: "X"))
        XCTAssertTrue(js.contains("font/otf"))
    }

    func testFontFamilyScriptImportedHasFontLoadCheck() {
        let js = ReaderStyler.fontFamilyScript(
            font: .embeddedDataURL(mimeType: "font/ttf", base64: "X"))
        XCTAssertTrue(js.contains("document.fonts.load"))
    }

    func testFontFamilyScriptImportedFallsBackOnFailure() {
        let js = ReaderStyler.fontFamilyScript(
            font: .embeddedDataURL(mimeType: "font/ttf", base64: "X"))
        XCTAssertTrue(js.contains("fallback"),
                      "Script must return 'fallback' on font load failure")
        XCTAssertTrue(js.contains(ReaderStyler.defaultFontStack),
                      "Fallback restores default font stack")
    }

    // MARK: - removalScript clears user font

    func testRemovalScriptClearsUserFontStyle() {
        let js = ReaderStyler.removalScript()
        XCTAssertTrue(js.contains(ReaderStyler.userFontStyleID))
        XCTAssertTrue(js.contains("--monori-font-family"))
    }

    // MARK: - wrappedDocument with font

    func testWrappedDocumentBuiltInUsesFontVariable() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9,
                                                font: .builtIn)
        XCTAssertTrue(html.contains("--monori-font-family"))
        XCTAssertTrue(html.contains("var(--monori-font-family)"))
        XCTAssertFalse(html.contains("MonoriUserFont"))
    }

    func testWrappedDocumentImportedEmbedsUserFont() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9,
                                                font: .embeddedDataURL(mimeType: "font/otf",
                                                                       base64: "BBBB"))
        XCTAssertTrue(html.contains("MonoriUserFont"))
        XCTAssertTrue(html.contains("data:font/otf;base64,BBBB"))
        XCTAssertTrue(html.contains("var(--monori-font-family)"))
        XCTAssertTrue(html.contains("Noto Serif TC"))
    }

    func testWrappedDocumentImportedKeepsTypographyVariables() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 21, lineHeight: 1.8,
                                                font: .embeddedDataURL(mimeType: "font/ttf",
                                                                       base64: "X"))
        XCTAssertTrue(html.contains("--monori-font-size: 21px"))
        XCTAssertTrue(html.contains("--monori-line-height: 1.80"))
    }

    func testWrappedDocumentImportedKeepsDarkMode() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9,
                                                font: .embeddedDataURL(mimeType: "font/ttf",
                                                                       base64: "X"))
        XCTAssertTrue(html.contains("#1C1B19"))
        XCTAssertTrue(html.contains("#F2F0ED"))
        XCTAssertTrue(html.contains("prefers-color-scheme: dark"))
    }

    func testWrappedDocumentDefaultParameterIsBuiltIn() {
        let html = ReaderStyler.wrappedDocument(inner: "<p>x</p>",
                                                fontSizePoints: 19, lineHeight: 1.9)
        XCTAssertFalse(html.contains("MonoriUserFont"))
        XCTAssertTrue(html.contains("Source Serif 4"))
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
