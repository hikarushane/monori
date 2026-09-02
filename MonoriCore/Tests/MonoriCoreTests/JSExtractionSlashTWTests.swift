import XCTest
import WebKit
@testable import MonoriCore

/// Exercises SlashTWThreadDetect.js and SlashTWThreadImport.js against fixture
/// HTML.
///
/// The DOM selectors in both scripts are generic `[class*="..."]` placeholders
/// -- the real waterfall.slashtw.space markup hasn't been inspected with
/// DevTools yet (it requires a logged-in session to reach at all) -- so these
/// fixtures are hand-built to match the task brief's assumed model (thread =
/// collection, each floor/post = one chapter, floor number as the chapter
/// title) rather than captured from the live site. They lock in the current,
/// intentionally-generic behavior; expect fixtures and selectors to be
/// revisited once real markup and the forum's actual chaptering convention
/// are known.
@MainActor
final class JSExtractionSlashTWTests: XCTestCase {

    // MARK: - Detect

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
        _ = try? await webView.evaluateJavaScript(JSAssets.slashtwThreadDetect)
        try await Task.sleep(for: .milliseconds(200))
        return collector.bodies
    }

    func testDetectPostsThreadTitleAndAuthor() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://waterfall.slashtw.space/thread/4118")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionName, "異世界水管工的日常連載串")
        XCTAssertEqual(link.creatorName, "阿水")
        XCTAssertEqual(link.collectionURL, "https://waterfall.slashtw.space/thread/4118")
    }

    func testDetectFallsBackToDocumentTitleAndNilAuthor() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page-minimal",
            pageURL: "https://waterfall.slashtw.space/thread/9001")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionName, "沒有標題元素的討論串 - 在水裡寫字",
                       "must fall back to document.title when no h1/[class*=title/subject] element exists")
        XCTAssertNil(link.creatorName,
                     "a thread URL carries no author identifier to fall back to (unlike CXC's " +
                     "/@username/work/N), so a missing author element must post nil, not a guess")
    }

    func testDetectWorksWithLegacyDiscuzURL() async throws {
        // The old Discuz host currently redirects to the new Waterfall one,
        // but both URL forms may still be encountered (e.g. a stale bookmark
        // or shared link), mirroring URLNormalizer.slashtwThreadID's own
        // dual-form parsing.
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://slashtw.space/forum.php?mod=viewthread&tid=4118")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionURL, "https://waterfall.slashtw.space/thread/4118",
                       "the posted collection URL is always the canonical Waterfall form, " +
                       "never the legacy Discuz query-string form")
    }

    func testDetectAllowsSlashTWSubdomains() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://forum.slashtw.space/thread/4118")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionURL, "https://waterfall.slashtw.space/thread/4118",
                       "collection URL is normalized to the canonical waterfall host " +
                       "regardless of the source subdomain")
    }

    func testDetectStaysSilentOnNonThreadPages() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://waterfall.slashtw.space/")
        XCTAssertTrue(bodies.isEmpty, "no banner metadata belongs on a non-thread page")
    }

    func testDetectStaysSilentOnDiscuzForumListingPage() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://slashtw.space/forum.php?mod=forumdisplay&fid=2")
        XCTAssertTrue(bodies.isEmpty, "a forum listing page (mod=forumdisplay) is not a thread")
    }

    func testDetectStaysSilentOnNonNumericThreadID() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://waterfall.slashtw.space/thread/abc")
        XCTAssertTrue(bodies.isEmpty, "a non-numeric thread id must never post")
    }

    func testDetectStaysSilentOnNonSlashTWHost() async throws {
        // Mirrors the hostname guard style of CXC/Vocus/AFF/AO3's detect
        // scripts (defense-in-depth against a lookalike path on a foreign host).
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://example.com/thread/4118")
        XCTAssertTrue(bodies.isEmpty, "a lookalike path on a non-slashtw host must never post")
    }

    func testDetectNeverLeaksBodyText() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page",
            pageURL: "https://waterfall.slashtw.space/thread/4118")
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        let joined = [link.collectionName, link.collectionURL, link.creatorName ?? ""].joined()
        XCTAssertFalse(joined.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
        XCTAssertFalse(joined.contains("<"))
    }

    // MARK: - Import

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
        try await runReturning(JSAssets.slashtwThreadImport,
                               fixture: "slashtw-thread-page",
                               pageURL: "https://waterfall.slashtw.space/thread/4118")
    }

    func testImportCollectsEveryFloorOnce() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5,
                       "the reply-list heading, the moderator note, and the OP-name badge " +
                       "(\"poster\" starts with \"post\") all match the broad " +
                       "[class*=post/reply/floor] selector but carry no link, and must be skipped")
    }

    func testImportTitlesAreFloorLabelsInOrder() async throws {
        let titles = try await importChapters().compactMap { $0["title"] as? String }
        XCTAssertEqual(titles, ["1樓", "2樓", "3樓", "4樓", "5樓"])
    }

    func testImportURLsAreAbsoluteAndSequential() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.compactMap { $0["url"] as? String }, [
            "https://waterfall.slashtw.space/thread/4118#pid1",
            "https://waterfall.slashtw.space/thread/4118#pid2",
            "https://waterfall.slashtw.space/thread/4118#pid3",
            "https://waterfall.slashtw.space/thread/4118#pid4",
            "https://waterfall.slashtw.space/thread/4118#pid5",
        ])
        // domOrder is recomputed from the accepted count, not the raw
        // NodeList index, so the three skipped no-link rows (heading, note,
        // OP-name badge) never leave gaps like [1,2,4,6,7].
        XCTAssertEqual(chapters.compactMap { $0["domOrder"] as? Int }, [0, 1, 2, 3, 4])
    }

    func testImportCarriesThreadMetadataOnEveryChapter() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5)
        XCTAssertTrue(chapters.allSatisfy { $0["collectionName"] as? String == "異世界水管工的日常連載串" })
        XCTAssertTrue(chapters.allSatisfy { $0["creatorName"] as? String == "阿水" })
        XCTAssertTrue(chapters.allSatisfy {
            ($0["collectionURL"] as? String) == "https://waterfall.slashtw.space/thread/4118"
        })
    }

    func testImportReturnsEmptyArrayWhenNoFloorsFound() async throws {
        let chapters = try await runReturning(
            JSAssets.slashtwThreadImport,
            fixture: "slashtw-thread-page-minimal",
            pageURL: "https://waterfall.slashtw.space/thread/9001")
        XCTAssertTrue(chapters.isEmpty)
    }

    func testImportNeverLeaksBodyText() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5)
        let joined = chapters
            .flatMap { [$0["title"] as? String ?? "", $0["url"] as? String ?? "",
                        $0["collectionName"] as? String ?? ""] }
            .joined()
        XCTAssertFalse(joined.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
        XCTAssertFalse(joined.contains("<"))
    }
}
