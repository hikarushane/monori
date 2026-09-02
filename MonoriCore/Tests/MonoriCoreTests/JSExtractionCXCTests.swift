import XCTest
import WebKit
@testable import MonoriCore

/// Exercises CXCWorkDetect.js and CXCWorkImport.js against fixture HTML.
///
/// The DOM selectors in both scripts are generic `[class*="..."]` placeholders
/// -- the real cxc.today markup hasn't been inspected with DevTools yet -- so
/// these fixtures are hand-built to match the task brief's described
/// structure (title, author below the cover, a chapter list with number/
/// title/word-count/free-or-paid marker per row) rather than captured from
/// the live site. They lock in the current, intentionally-generic behavior;
/// expect fixtures and selectors to be revisited once real markup is known.
@MainActor
final class JSExtractionCXCTests: XCTestCase {

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
        _ = try? await webView.evaluateJavaScript(JSAssets.cxcWorkDetect)
        try await Task.sleep(for: .milliseconds(200))
        return collector.bodies
    }

    func testDetectPostsWorkTitleAndAuthor() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://cxc.today/zh/@yeyu/work/38982")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionName, "薄荷貓耳少女的異世界奇幻冒險")
        XCTAssertEqual(link.creatorName, "夜雨微涼")
        XCTAssertEqual(link.collectionURL, "https://cxc.today/zh/@yeyu/work/38982")
    }

    func testDetectFallsBackToDocumentTitleAndUsername() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page-minimal",
            pageURL: "https://cxc.today/zh/@fallback_user/work/9001")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionName, "沒有標題元素的作品 - CXC",
                       "must fall back to document.title when no h1/[class*=title] element exists")
        XCTAssertEqual(link.creatorName, "fallback_user",
                       "must fall back to the URL username when no author/creator element exists")
    }

    func testDetectFiresOnChapterSubpageToo() async throws {
        // The path regex has no end anchor, so it also matches chapter
        // subpages (mirrors AO3WorkDetect.js firing on any /works/N page).
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://cxc.today/zh/@yeyu/work/38982/chapter/3")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionURL, "https://cxc.today/zh/@yeyu/work/38982",
                       "the posted collection URL is always the canonical work root, never the chapter suffix")
    }

    func testDetectAllowsCXCSubdomains() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://bl.cxc.today/zh/@yeyu/work/38982")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionURL, "https://cxc.today/zh/@yeyu/work/38982",
                       "collection URL is normalized to the main cxc.today host regardless of subdomain")
    }

    func testDetectWorksWithoutLanguagePrefix() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://cxc.today/@yeyu/work/38982")
        XCTAssertEqual(bodies.count, 1)
    }

    func testDetectStaysSilentOnNonWorkPages() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://cxc.today/zh/explore")
        XCTAssertTrue(bodies.isEmpty, "no banner metadata belongs on a non-work page")
    }

    func testDetectStaysSilentOnNonCXCHost() async throws {
        // The brief's reference snippet has no hostname check at all; this
        // locks in the hostname guard added to match the Vocus/AFF/AO3
        // detect scripts' defense-in-depth style.
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://example.com/@yeyu/work/38982")
        XCTAssertTrue(bodies.isEmpty, "a lookalike path on a non-CXC host must never post")
    }

    func testDetectNeverLeaksBodyText() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://cxc.today/zh/@yeyu/work/38982")
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
        try await runReturning(JSAssets.cxcWorkImport,
                               fixture: "cxc-work-page",
                               pageURL: "https://cxc.today/zh/@yeyu/work/38982")
    }

    func testImportCollectsEveryChapterOnce() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5,
                       "the section heading and the paid-section note both match the broad " +
                       "[class*=chapter] selector but carry no link, and must be skipped")
    }

    func testImportTitlesInOrder() async throws {
        let titles = try await importChapters().compactMap { $0["title"] as? String }
        XCTAssertEqual(titles, [
            "初次見面的貓耳少女",
            "薄荷糖與月光",
            "異世界的第一場雨",
            "貓耳少女的祕密",
            "尾聲：回家的路",
        ])
    }

    func testImportURLsAreAbsoluteAndSequential() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.compactMap { $0["url"] as? String }, [
            "https://cxc.today/zh/@yeyu/work/38982/chapter/1",
            "https://cxc.today/zh/@yeyu/work/38982/chapter/2",
            "https://cxc.today/zh/@yeyu/work/38982/chapter/3",
            "https://cxc.today/zh/@yeyu/work/38982/chapter/4",
            "https://cxc.today/zh/@yeyu/work/38982/chapter/5",
        ])
        // domOrder is recomputed from the accepted count, not the raw
        // NodeList index, so the two skipped no-link rows (at NodeList
        // positions 0 and 4) never leave gaps like [1,2,3,5,6].
        XCTAssertEqual(chapters.compactMap { $0["domOrder"] as? Int }, [0, 1, 2, 3, 4])
    }

    func testImportMarksFreeAndPaidChaptersCorrectly() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.compactMap { $0["isFree"] as? Bool },
                       [true, true, false, false, true])
    }

    func testImportCarriesWorkMetadataOnEveryChapter() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5)
        XCTAssertTrue(chapters.allSatisfy { $0["collectionName"] as? String == "薄荷貓耳少女的異世界奇幻冒險" })
        XCTAssertTrue(chapters.allSatisfy { $0["creatorName"] as? String == "夜雨微涼" })
        XCTAssertTrue(chapters.allSatisfy {
            ($0["collectionURL"] as? String) == "https://cxc.today/zh/@yeyu/work/38982"
        })
    }

    func testImportReturnsEmptyArrayWhenNoChaptersFound() async throws {
        let chapters = try await runReturning(
            JSAssets.cxcWorkImport,
            fixture: "cxc-work-page-minimal",
            pageURL: "https://cxc.today/zh/@fallback_user/work/9001")
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
