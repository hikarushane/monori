import XCTest
import WebKit
@testable import MonoriCore

/// Exercises CXCWorkDetect.js and CXCWorkImport.js against fixture HTML
/// modeled after the real cxc.today DOM structure (inspected 2026-09).
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
        XCTAssertEqual(link.collectionURL, "https://cxc.today/@yeyu/work/38982")
    }

    func testDetectFallsBackToDocumentTitleAndUsername() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page-minimal",
            pageURL: "https://cxc.today/zh/@fallback_user/work/9001")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionName, "沒有標題元素的作品",
                       "title is the first segment of document.title split on ' | '")
        XCTAssertEqual(link.creatorName, "無名作者",
                       "creatorName prefers the display name from document.title split on ' | '")
    }

    func testDetectFiresOnChapterSubpageToo() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://cxc.today/zh/@yeyu/work/38982/reader/1003")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionURL, "https://cxc.today/@yeyu/work/38982",
                       "the posted collection URL is always the canonical work root, never the reader suffix")
    }

    func testDetectAllowsCXCSubdomains() async throws {
        let bodies = try await runDetect(
            fixture: "cxc-work-page",
            pageURL: "https://bl.cxc.today/zh/@yeyu/work/38982")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionURL, "https://cxc.today/@yeyu/work/38982",
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
        XCTAssertEqual(chapters.count, 5)
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
            "https://cxc.today/@yeyu/work/38982/reader/1001",
            "https://cxc.today/@yeyu/work/38982/reader/1002",
            "https://cxc.today/@yeyu/work/38982/reader/1003",
            "https://cxc.today/@yeyu/work/38982/reader/1004",
            "https://cxc.today/@yeyu/work/38982/reader/1005",
        ])
        XCTAssertEqual(chapters.compactMap { $0["domOrder"] as? Int }, [0, 1, 2, 3, 4])
    }

    func testImportCarriesWorkMetadataOnEveryChapter() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5)
        XCTAssertTrue(chapters.allSatisfy { $0["collectionName"] as? String == "薄荷貓耳少女的異世界奇幻冒險" })
        XCTAssertTrue(chapters.allSatisfy { $0["creatorName"] as? String == "夜雨微涼" })
        XCTAssertTrue(chapters.allSatisfy {
            ($0["collectionURL"] as? String) == "https://cxc.today/@yeyu/work/38982"
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
