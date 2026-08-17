import XCTest
import WebKit
@testable import MonoriCore

/// Page-side extraction for AO3 work pages. Both scripts run as the body of an
/// async function (WKWebView `callAsyncJavaScript`), so they must end in
/// `return` — a bare expression resolves to `undefined` and reaches Swift as
/// nil, which is what made every import fall back to the "AO3 Work" title.
@MainActor
final class AO3ExtractionTests: XCTestCase {

    private func loadWorkPage(
        pageURL: String = "https://archiveofourown.org/works/12345"
    ) async throws -> WKWebView {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: WKWebViewConfiguration())
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ao3-work-page", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(html, baseURL: try XCTUnwrap(URL(string: pageURL)))
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        return webView
    }

    // MARK: - AO3WorkMeta.js

    private func workMeta(pageURL: String = "https://archiveofourown.org/works/12345")
        async throws -> [String: Any] {
        let webView = try await loadWorkPage(pageURL: pageURL)
        let result = try await webView.callAsyncJavaScript(JSAssets.ao3WorkMeta,
                                                           contentWorld: .page)
        return try XCTUnwrap(result as? [String: Any],
                             "the meta script must return a dictionary, not \(String(describing: result))")
    }

    func testWorkMetaReturnsTitle() async throws {
        let meta = try await workMeta()
        XCTAssertEqual(meta["title"] as? String, "紙月亮 Paper Moons",
                       "AO3 renders the title across several lines; it must come back trimmed")
    }

    func testWorkMetaReturnsAuthor() async throws {
        let meta = try await workMeta()
        XCTAssertEqual(meta["author"] as? String, "shanewrites")
    }

    // MARK: - AO3WorkContent.js

    func testWorkContentIsTheChapterBodyNotTheSummary() async throws {
        let webView = try await loadWorkPage()
        let result = try await webView.callAsyncJavaScript(JSAssets.ao3WorkContent,
                                                           contentWorld: .page)
        let content = try XCTUnwrap(result as? String)
        // The summary blockquote also carries .userstuff and comes first in the
        // DOM, so a bare `.userstuff` selector imports the summary as chapter 1.
        XCTAssertFalse(content.contains("SUMMARY_MUST_NOT_BE_IMPORTED_AS_CONTENT"))
        XCTAssertTrue(content.contains("First paragraph of the story."))
    }

    // MARK: - AO3WorkDetect.js

    private func runDetect(pageURL: String) async throws -> [Any] {
        final class Collector: NSObject, WKScriptMessageHandler {
            var bodies: [Any] = []
            func userContentController(_ ucc: WKUserContentController,
                                       didReceive message: WKScriptMessage) {
                bodies.append(message.body)
            }
        }
        let collector = Collector()
        let config = WKWebViewConfiguration()
        config.userContentController.add(collector, name: "monoriCollectionLink")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: config)
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ao3-work-page", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(html, baseURL: try XCTUnwrap(URL(string: pageURL)))
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        _ = try? await webView.evaluateJavaScript(JSAssets.ao3WorkDetect)
        try await Task.sleep(for: .milliseconds(200))
        return collector.bodies
    }

    func testDetectPostsWorkTitleAndAuthor() async throws {
        let bodies = try await runDetect(pageURL: "https://archiveofourown.org/works/12345")
        XCTAssertEqual(bodies.count, 1)
        let link = try PayloadValidator.validateCollectionLink(try XCTUnwrap(bodies.first)).get()
        XCTAssertEqual(link.collectionName, "紙月亮 Paper Moons")
        XCTAssertEqual(link.creatorName, "shanewrites",
                       "the library row shows the creator; Vocus and AFF already post it")
        XCTAssertEqual(link.collectionURL, "https://archiveofourown.org/works/12345")
    }

    func testDetectStaysSilentOffWorkPages() async throws {
        let bodies = try await runDetect(pageURL: "https://archiveofourown.org/")
        XCTAssertTrue(bodies.isEmpty)
    }
}
