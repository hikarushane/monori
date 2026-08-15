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
        XCTAssertEqual(chapters.count, 5,
                       "aside and dialog each render the full TOC; both copies must collapse to one")
    }

    func testSkipsForewordAndContinueRow() async throws {
        let titles = try await importChapters().compactMap { $0["title"] as? String }
        XCTAssertEqual(titles.count, 5)
        XCTAssertFalse(titles.contains { $0.localizedCaseInsensitiveContains("Foreword") })
        XCTAssertFalse(titles.contains { $0.contains("▶") })
        XCTAssertFalse(titles.contains { $0.contains("Continue") })
    }

    func testTitlesDropTheNumberBadge() async throws {
        let titles = try await importChapters().compactMap { $0["title"] as? String }
        XCTAssertEqual(titles, [
            "Chapter 1: The Signal in the Static",
            "Chapter 2: Cartography of Forgetting",
            "Chapter 3: Letters Never Sent",
            "Chapter 4: The Geometry of Rain",
            "Chapter 5: Exit Wounds",
        ])
    }

    func testURLsAreAbsoluteAndOrdered() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.compactMap { $0["url"] as? String }, [
            "https://www.asianfanfics.com/story/view/1754805/1/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/2/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/3/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/4/paper-ghosts-ipsum",
            "https://www.asianfanfics.com/story/view/1754805/5/paper-ghosts-ipsum",
        ])
        XCTAssertEqual(chapters.compactMap { $0["domOrder"] as? Int }, [0, 1, 2, 3, 4])
    }

    func testCarriesStoryMetadataFromHeader() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5)
        XCTAssertTrue(chapters.allSatisfy { $0["collectionName"] as? String == "Paper Ghosts (Ipsum)" })
        XCTAssertTrue(chapters.allSatisfy { $0["creatorName"] as? String == "shane245" })
        XCTAssertTrue(chapters.allSatisfy {
            ($0["collectionURL"] as? String) == "https://www.asianfanfics.com/story/view/1754805/paper-ghosts-ipsum"
        })
    }

    func testNeverLeaksBodyText() async throws {
        let chapters = try await importChapters()
        XCTAssertEqual(chapters.count, 5)
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
}
