import XCTest
import WebKit
@testable import ChapterlyCore

@MainActor
final class JSExtractionTests: XCTestCase {

    final class Collector: NSObject, WKScriptMessageHandler {
        var bodies: [Any] = []
        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            bodies.append(message.body)
        }
    }

    private func runScript(_ script: String, fixture: String, handlerName: String) async throws -> [Any] {
        let collector = Collector()
        let config = WKWebViewConfiguration()
        config.userContentController.add(collector, name: handlerName)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: config)
        let url = Bundle.module.url(forResource: fixture, withExtension: "html")!
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.patreon.com/")!)

        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        // callAsyncJavaScript so scripts may use top-level await/return and the
        // test resumes only after the script (including its scroll loop) finishes.
        _ = try? await webView.callAsyncJavaScript(script, contentWorld: .page)
        try await Task.sleep(for: .milliseconds(200))
        return collector.bodies
    }

    func testCollectionImportExtractsMetadataOnly() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page",
                                         handlerName: "chapterlyImport")
        XCTAssertEqual(bodies.count, 5)

        var payloads: [ImporterChapterPayload] = []
        for body in bodies {
            payloads.append(try PayloadValidator.validateImporterChapter(body).get())
        }
        let allText = payloads.flatMap { [$0.title, $0.url, $0.collectionName, $0.collectionURL,
                                          $0.visibleDateText ?? ""] }.joined()
        XCTAssertFalse(allText.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
        XCTAssertFalse(allText.contains("<"))

        XCTAssertEqual(payloads[0].title, "3 試探")
        XCTAssertEqual(payloads[0].domOrder, 0)
        XCTAssertEqual(payloads.map(\.title).filter { $0.contains("愛") }.count, 1)
        XCTAssertTrue(payloads.allSatisfy { $0.collectionName == "【更新中】焚心 The Burning Heart" })
    }

    func testExternalDecoySkippedAfterNormalization() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page",
                                         handlerName: "chapterlyImport")
        let payloads = bodies.compactMap { try? PayloadValidator.validateImporterChapter($0).get() }
        let merged = ChapterMapMerger.merge(existing: [], incoming: payloads)
        XCTAssertEqual(merged.count, 4)
        XCTAssertEqual(merged.map(\.title), ["3 試探", "4 愛", "5 脣瓣", "6 浴室的紅櫻桃(R18+)"])
    }

    func testCollectionImportUsesSafeMetadataFallbacksWhenAnchorTextIsEmpty() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_empty_anchor_text",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.map(\.title), [
            "11 aria title",
            "12 title attribute",
            "13 slug fallback"
        ])
        let allText = payloads.flatMap { [$0.title, $0.url, $0.collectionName, $0.collectionURL,
                                          $0.visibleDateText ?? ""] }.joined()
        XCTAssertFalse(allText.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
    }

    func testCollectionImportCapsLargeCardTextBeforeValidation() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_large_card_text",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.count, 1)
        XCTAssertLessThanOrEqual(payloads[0].title.utf8.count, PayloadValidator.maxFieldLength)
        XCTAssertLessThanOrEqual(payloads[0].collectionName.utf8.count, PayloadValidator.maxFieldLength)
    }

    func testCollectionImportPrefersCardTitleOverExcerptText() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_card_excerpt",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.map(\.title), ["真正的文章標題", "第二篇標題"])
        let allText = payloads.flatMap { [$0.title, $0.url, $0.collectionName, $0.collectionURL,
                                          $0.visibleDateText ?? ""] }.joined()
        XCTAssertFalse(allText.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
    }

    func testCollectionImportExtractsSiblingTeaserAsExcerpt() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_sibling_teaser",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.map(\.title), ["陽光普照 19", "陽光普照 18"])
        XCTAssertEqual(payloads[0].excerpt,
                       "隨著玻璃門被輕輕推開，掛在門上的銅製風鈴發出了一串清脆的叮噹聲。")
        XCTAssertEqual(payloads[1].excerpt,
                       "等到朝陽完全升起，金燦燦的陽光照亮了整座社區公園。")
    }

    func testCollectionImportExtractsInAnchorExcerpt() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_card_excerpt",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.count, 2)
        XCTAssertNotNil(payloads[0].excerpt)
        XCTAssertFalse(payloads.map(\.title).joined().contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
    }

    func testCollectionImportIncludesCreatorNameFromPageTitle() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_card_excerpt",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.map(\.creatorName), ["ocean", "ocean"])
    }

    func testCollectionImportLoadsLazyContentBeforeScraping() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_lazy",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.map(\.title),
                       ["9 最新章", "8 次新章", "7 中段章", "6 更舊章", "5 最舊章"])
        XCTAssertEqual(payloads.map(\.domOrder), [0, 1, 2, 3, 4])
    }

    func testCollectionImportClicksLoadMoreUntilExhausted() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page_load_more",
                                         handlerName: "chapterlyImport")
        let payloads = try bodies.map { try PayloadValidator.validateImporterChapter($0).get() }
        XCTAssertEqual(payloads.map(\.title),
                       ["20 最新章", "19 章", "18 章", "17 章", "16 章", "15 最舊章"])
        XCTAssertEqual(payloads.map(\.domOrder), [0, 1, 2, 3, 4, 5])
    }

    func testCardTreatmentMakesCardsClickableAndCollapsesTeasers() async throws {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: config)
        let url = Bundle.module.url(forResource: "post_cards", withExtension: "html")!
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.patreon.com/")!)
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        _ = try? await webView.callAsyncJavaScript(JSAssets.cardTreatment, contentWorld: .page)
        try await Task.sleep(for: .milliseconds(200))

        // Record link clicks instead of navigating away from the fixture.
        _ = try await webView.evaluateJavaScript("""
        (function () {
          window.__clicked = null;
          document.addEventListener("click", function (e) {
            var a = e.target.closest("a");
            if (a) { window.__clicked = a.href; e.preventDefault(); }
          }, true);
          return true;
        })();
        """)

        let checks = try await webView.evaluateJavaScript("""
        (function () {
          var card = document.getElementById("card-1");
          document.getElementById("teaser-1").click();
          return [
            !!document.getElementById("chapterly-card-style"),
            getComputedStyle(card).webkitUserSelect === "none",
            getComputedStyle(document.getElementById("more-1")).display === "none",
            getComputedStyle(document.getElementById("more-2")).display === "none",
            document.querySelector("#card-1 .post-content").classList.contains("chapterly-fade"),
            window.__clicked || ""
          ];
        })();
        """)
        let values = try XCTUnwrap(checks as? [Any])
        XCTAssertEqual(values[0] as? Bool, true, "style element missing")
        XCTAssertEqual(values[1] as? Bool, true, "card text still selectable")
        XCTAssertEqual(values[2] as? Bool, true, "English Show more still visible")
        XCTAssertEqual(values[3] as? Bool, true, "中文顯示更多 still visible")
        XCTAssertEqual(values[4] as? Bool, true, "teaser fade not applied")
        XCTAssertEqual(values[5] as? String, "https://www.patreon.com/posts/26-901",
                       "tapping teaser did not open the card's post")
    }

    func testCollectionDetectFindsSeriesLink() async throws {
        let bodies = try await runScript(JSAssets.collectionDetect,
                                         fixture: "post_page",
                                         handlerName: "chapterlyCollectionLink")
        XCTAssertEqual(bodies.count, 1)
        let p = try PayloadValidator.validateCollectionLink(bodies[0]).get()
        XCTAssertEqual(p.collectionName, "【更新中】焚心 The Burning Heart")
        XCTAssertEqual(URLNormalizer.normalize(p.collectionURL)?.absoluteString,
                       "https://www.patreon.com/collection/9999")
        XCTAssertFalse(p.collectionName.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
    }
}
