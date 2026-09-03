import XCTest
import WebKit
@testable import MonoriCore

/// Exercises SlashTWThreadDetect.js and SlashTWThreadImport.js against fixture
/// HTML that mirrors the real waterfall.slashtw.space DOM (verified 2026-09).
///
/// Key Waterfall selectors:
///   Thread title:    h1 > a.title-link
///   Author:          .author-info a[href*="/user/"] > span
///   Floor container: .card-post.thread (bare .card-post = login overlay/footer)
///   Chapter title:   .subtitle h2 > a.title-link
///   Floor number:    a.floor-link
///   Permalink:       h2 a.title-link[href="/thread/{id}#post{postId}"]
///   Floor body:      .card-content > div.content (then an empty div.content)
///   Comment chrome:  .card-content > div.comments (dropped)
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

    func testDetectFallsBackToStrippedDocumentTitleAndNilAuthor() async throws {
        let bodies = try await runDetect(
            fixture: "slashtw-thread-page-minimal",
            pageURL: "https://waterfall.slashtw.space/thread/9001")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionName, "沒有標題元素的討論串",
                       "must fall back to document.title with the ' - 在水裡寫字' suffix stripped")
        XCTAssertNil(link.creatorName,
                     "a minimal page has no .author-info element, so creatorName must be nil")
    }

    func testDetectWorksWithLegacyDiscuzURL() async throws {
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
                       "the login overlay (.card-post without .thread) and the footer card " +
                       "must both be skipped — only .card-post.thread elements are chapters")
    }

    func testImportTitlesAreChapterHeadings() async throws {
        let titles = try await importChapters().compactMap { $0["title"] as? String }
        XCTAssertEqual(titles, [
            "序章：初來乍到",
            "第一章：水管工上工",
            "第二章：異世界的第一天",
            "第三章：管線裡的秘密",
            "尾聲：回家的水管"
        ])
    }

    func testImportURLsArePerFloorPermalinks() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.compactMap { $0["url"] as? String }, [
            "https://waterfall.slashtw.space/thread/4118#post1001",
            "https://waterfall.slashtw.space/thread/4118#post1002",
            "https://waterfall.slashtw.space/thread/4118#post1003",
            "https://waterfall.slashtw.space/thread/4118#post1004",
            "https://waterfall.slashtw.space/thread/4118#post1005",
        ])
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

    func testImportExtractsFloorBodyFromContentBlocksAndDropsComments() async throws {
        // Real Waterfall floors (1F in the fixture) keep only the div.content
        // blocks: the thread title, heading row, comment thread, login prompt,
        // reaction chips and Discuz's edit stamp all stay out. Floors without a
        // div.content (2F–5F) go through the exclusion fallback.
        let chapters = try await importChapters()
        let bodies = chapters.map { $0["contentHTML"] as? String }
        XCTAssertEqual(bodies.count, 5)
        XCTAssertTrue(bodies.allSatisfy { $0 != nil }, "every floor carries contentHTML")

        let first = try XCTUnwrap(bodies[0])
        XCTAssertTrue(first.contains("序章內容") && first.contains("第二段"))
        XCTAssertTrue(first.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"),
                      "contentHTML deliberately carries the full body")
        XCTAssertFalse(first.contains("異世界水管工的日常連載串"), "thread title block (.title) is excluded")
        XCTAssertFalse(first.contains("序章：初來乍到"), "chapter heading row (.subtitle) is excluded")
        XCTAssertFalse(first.contains("floor-link"), "floor number link leaves with .subtitle")
        for chrome in ["還沒有任何人留言", "登入", "寫得太好了", "dropdown-content", "comments"] {
            XCTAssertFalse(first.contains(chrome), "comment/reaction chrome must be dropped: \(chrome)")
        }
        XCTAssertFalse(first.contains("本文最後由"), "Discuz edit stamp (i.pstatus) is dropped")
        XCTAssertFalse(first.contains("class=\"content\""), "body blocks are unwrapped")

        let second = try XCTUnwrap(bodies[1])
        XCTAssertTrue(second.contains("第一章內容") && second.contains("第一章第二段"),
                      "fallback: bare paragraphs directly under .card-content are the body")

        let third = try XCTUnwrap(bodies[2])
        XCTAssertTrue(third.contains("小標：管線"),
                      "fallback: only direct children of .card-content named .title are excluded; nested ones survive")
        XCTAssertFalse(third.contains("FALLBACK_COMMENTS_TRAP"), "fallback also drops .comments")

        let fourth = try XCTUnwrap(bodies[3])
        XCTAssertTrue(fourth.contains("第三章內容"))
        XCTAssertFalse(fourth.lowercased().contains("<script"), "script elements are dropped in JS")

        let fifth = try XCTUnwrap(bodies[4])
        XCTAssertTrue(fifth.contains("<img"), "an image-only body still counts as content")
    }
}
