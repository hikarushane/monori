import XCTest
import WebKit
@testable import MonoriCore

@MainActor
final class AFFExtractionTests: XCTestCase {

    /// Loads a fixture at a real AFF URL so page-side `location.*` checks behave,
    /// then runs a script that ends in `return <value>` via callAsyncJavaScript.
    private func runReturning(_ script: String,
                              fixture: String,
                              pageURL: String) async throws -> [[String: Any]] {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: WKWebViewConfiguration())
        let url = Bundle.module.url(forResource: fixture, withExtension: "html")!
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(html, baseURL: URL(string: pageURL)!)
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let result = try await webView.callAsyncJavaScript(script, contentWorld: .page)
        return (result as? [[String: Any]]) ?? []
    }

    private func importChapters() async throws -> [[String: Any]] {
        try await runReturning(JSAssets.affStoryImport,
                               fixture: "aff-story-foreword",
                               pageURL: "https://www.asianfanfics.com/story/view/1754805/paper-ghosts-ipsum")
    }

    func testImportsEveryChapterOnce() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 12,
                       "aside and dialog each render the full TOC; both copies must collapse to one")
    }

    func testSkipsForewordAndContinueRow() async throws {
        let titles = try await importChapters().compactMap { $0["title"] as? String }
        XCTAssertEqual(titles.count, 12)
        XCTAssertFalse(titles.contains { $0.localizedCaseInsensitiveContains("Foreword") })
        XCTAssertFalse(titles.contains { $0.contains("▶") })
        XCTAssertFalse(titles.contains { $0.contains("Continue") })
    }

    func testTitlesDropTheNumberBadge() async throws {
        let titles = try await importChapters().compactMap { $0["title"] as? String }
        // Chapters 10-12 must sort numerically after 9, not lexically between 1 and 2.
        XCTAssertEqual(titles, [
            "Chapter 1: The Signal in the Static",
            "Chapter 2: Cartography of Forgetting",
            "Chapter 3: Letters Never Sent",
            "Chapter 4: The Geometry of Rain",
            "Chapter 5: Exit Wounds",
            "Chapter 6: The Weight of Ash",
            "Chapter 7: What the Tide Keeps",
            "Chapter 8: A Grammar of Absence",
            "Chapter 9: The Last Known Address",
            "Chapter 10: Static Bloom",
            "Chapter 11: The Distance Between Sentences",
            "Chapter 12: Everything We Didn't Say",
        ])
    }

    func testURLsAreAbsoluteAndOrdered() async throws {
        let chapters = try await importChapters()
        // Chapters 10-12 must sort numerically after 9, not lexically between 1 and 2.
        XCTAssertEqual(chapters.compactMap { $0["url"] as? String }, [
            "https://www.asianfanfics.com/story/view/1754805/1/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/2/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/3/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/4/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/5/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/6/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/7/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/8/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/9/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/10/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/11/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/12/paper-ghosts-ipsum",
        ])
        XCTAssertEqual(chapters.compactMap { $0["domOrder"] as? Int }, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    }

    func testCarriesStoryMetadataFromHeader() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 12)
        XCTAssertTrue(chapters.allSatisfy { $0["collectionName"] as? String == "Paper Ghosts (Ipsum)" })
        XCTAssertTrue(chapters.allSatisfy { $0["creatorName"] as? String == "shane245" })
        XCTAssertTrue(chapters.allSatisfy {
            ($0["collectionURL"] as? String) == "https://www.asianfanfics.com/story/view/1754805/paper-ghosts-ipsum"
        })
    }

    func testNeverLeaksBodyText() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 12)
        let joined = chapters
            .flatMap { [$0["title"] as? String ?? "", $0["url"] as? String ?? "",
                        $0["collectionName"] as? String ?? ""] }
            .joined()
        XCTAssertFalse(joined.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
        XCTAssertFalse(joined.contains("<"))
    }

    func testFallsBackToLinkScanWhenTOCAbsent() async throws {
        let chapters = try await runReturning(
            JSAssets.affStoryImport,
            fixture: "aff-story-foreword-no-toc",
            pageURL: "https://www.asianfanfics.com/story/view/1470000/companion")
        XCTAssertEqual(chapters.count, 1)
        let first = try XCTUnwrap(chapters.first)
        XCTAssertEqual(first["url"] as? String,
                       "https://www.asianfanfics.com/story/view/1470000/1/companion")
        XCTAssertEqual(first["title"] as? String, "Chapter 1: Companion",
                       "the longest visible label for a chapter number wins over 'Start reading →'")
        XCTAssertEqual(first["collectionName"] as? String, "Companion")
    }

    private final class Collector: NSObject, WKScriptMessageHandler {
        var bodies: [Any] = []
        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            bodies.append(message.body)
        }
    }

    private func runDetect(fixture: String, pageURL: String) async throws -> [Any] {
        let collector = Collector()
        let config = WKWebViewConfiguration()
        config.userContentController.add(collector, name: "monoriCollectionLink")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: config)
        let url = Bundle.module.url(forResource: fixture, withExtension: "html")!
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(html, baseURL: URL(string: pageURL)!)
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        _ = try? await webView.evaluateJavaScript(JSAssets.affStoryDetect)
        try await Task.sleep(for: .milliseconds(200))
        return collector.bodies
    }

    func testDetectPostsStoryTitleAndAuthor() async throws {
        let bodies = try await runDetect(
            fixture: "aff-story-foreword",
            pageURL: "https://www.asianfanfics.com/story/view/1754805/paper-ghosts-ipsum")
        XCTAssertEqual(bodies.count, 1)
        let body = try XCTUnwrap(bodies.first)
        let link = try PayloadValidator.validateCollectionLink(body).get()
        XCTAssertEqual(link.collectionName, "Paper Ghosts (Ipsum)")
        XCTAssertEqual(link.creatorName, "shane245")
        XCTAssertEqual(link.collectionURL,
                       "https://www.asianfanfics.com/story/view/1754805/paper-ghosts-ipsum")
    }

    func testDetectStaysSilentOnChapterPages() async throws {
        let bodies = try await runDetect(
            fixture: "aff-story-foreword",
            pageURL: "https://www.asianfanfics.com/story/view/1754805/3/paper-ghosts-ipsum")
        XCTAssertTrue(bodies.isEmpty, "the banner belongs on the foreword page only")
    }

    // MARK: - CSS ruleset coverage
    //
    // AFFReaderRuleset.css and AFFBrowseRuleset.css are pure presentation —
    // nothing about them is exercised by the JS import/detect tests above.
    // These load the same foreword fixture into a live WKWebView, inject the
    // real stylesheet via ReaderStyler, and read back `getComputedStyle` so a
    // future redesign that silently breaks either ruleset fails loudly here
    // instead of just breaking the reader chrome on-device.

    /// Loads the foreword fixture at its real AFF URL and injects `script`
    /// (a `ReaderStyler` injection script) into the resulting page.
    private func loadAFFFixtureAndInject(_ script: String) async throws -> WKWebView {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: WKWebViewConfiguration())
        let url = Bundle.module.url(forResource: "aff-story-foreword", withExtension: "html")!
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(
            html,
            baseURL: URL(string: "https://www.asianfanfics.com/story/view/1754805/paper-ghosts-ipsum")!)
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        _ = try await webView.evaluateJavaScript(script)
        return webView
    }

    /// Computed `display` of the first element matching `selector`. Throws
    /// (failing the test) if the selector matches nothing, rather than
    /// silently comparing against `nil`.
    private func computedDisplay(_ selector: String, in webView: WKWebView) async throws -> String {
        let result = try await webView.evaluateJavaScript("""
        getComputedStyle(document.querySelector('\(selector)')).display
        """)
        return try XCTUnwrap(result as? String,
                             "selector '\(selector)' matched nothing in the fixture")
    }

    /// Computed `display` of every element matching `selector`, in document order.
    private func computedDisplays(_ selector: String, in webView: WKWebView) async throws -> [String] {
        let result = try await webView.evaluateJavaScript("""
        Array.from(document.querySelectorAll('\(selector)')).map(function (el) {
          return getComputedStyle(el).display;
        })
        """)
        return (result as? [String]) ?? []
    }

    func testAffReaderRulesetHidesSiteChromeButKeepsChapterAndComments() async throws {
        let webView = try await loadAFFFixtureAndInject(ReaderStyler.affInjectionScript())

        // The fixture has two `body > header` elements (language bar + site
        // nav); both must go, including the one with #site-header.
        let headerDisplays = try await computedDisplays("body > header", in: webView)
        XCTAssertFalse(headerDisplays.isEmpty,
                       "fixture must contain body > header elements to exercise this rule")
        XCTAssertTrue(headerDisplays.allSatisfy { $0 == "none" },
                      "every body > header, including #site-header, must be hidden")

        let footerDisplay = try await computedDisplay("footer#site-footer", in: webView)
        XCTAssertEqual(footerDisplay, "none")
        let dialogDisplay = try await computedDisplay("dialog", in: webView)
        XCTAssertEqual(dialogDisplay, "none", "the mobile TOC dialog must be hidden")
        let asideDisplay = try await computedDisplay("aside", in: webView)
        XCTAssertEqual(asideDisplay, "none", "the desktop TOC sidebar must be hidden in reader mode")
        let adDisplay = try await computedDisplay("ins.adsbygoogle", in: webView)
        XCTAssertEqual(adDisplay, "none")

        let bodyTextDisplay = try await computedDisplay("#bodyText", in: webView)
        XCTAssertNotEqual(bodyTextDisplay, "none", "chapter text must stay visible")
        let commentsDisplay = try await computedDisplay("section#comments", in: webView)
        XCTAssertNotEqual(commentsDisplay, "none", "the comment thread must stay visible")
    }

    func testAffBrowseRulesetOnlyHidesAds() async throws {
        let webView = try await loadAFFFixtureAndInject(ReaderStyler.affBrowseInjectionScript())

        let adDisplay = try await computedDisplay("ins.adsbygoogle", in: webView)
        XCTAssertEqual(adDisplay, "none")

        // Browse mode keeps the site chrome — it only hides ads.
        let bodyTextDisplay = try await computedDisplay("#bodyText", in: webView)
        XCTAssertNotEqual(bodyTextDisplay, "none", "browse mode must not touch the article body")
        let headerDisplay = try await computedDisplay("#site-header", in: webView)
        XCTAssertNotEqual(headerDisplay, "none", "browse mode must keep the site header, unlike reader mode")
    }
}
