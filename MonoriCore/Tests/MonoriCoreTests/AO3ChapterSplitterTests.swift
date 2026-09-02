import XCTest
@testable import MonoriCore

final class AO3ChapterSplitterTests: XCTestCase {
    func testChapterFetchesRemainPacedAfterAnEarlierFetchFails() async {
        let entries = [
            AO3ChapterSplitter.NavigateEntry(
                title: "One", chapterPath: "/works/1/chapters/11", dateText: nil),
            AO3ChapterSplitter.NavigateEntry(
                title: "Two", chapterPath: "/works/1/chapters/12", dateText: nil),
            AO3ChapterSplitter.NavigateEntry(
                title: "Three", chapterPath: "/works/1/chapters/13", dateText: nil),
        ]
        let chapterPage = """
        <html><body><div class="userstuff module"><p>Chapter text</p></div></body></html>
        """
        var firstRequest = true
        var serverReady = false
        var waitCount = 0

        let fetched = await AO3ChapterSplitter.fetchChapterContents(
            entries: entries,
            waitBetweenRequests: {
                waitCount += 1
                serverReady = true
            },
            fetchPage: { _ in
                if firstRequest {
                    firstRequest = false
                    return nil
                }
                guard serverReady else { return nil }
                serverReady = false
                return chapterPage
            })

        XCTAssertEqual(fetched.map(\.entry.title), ["Two", "Three"])
        XCTAssertEqual(waitCount, 2, "every request after the first must be paced")
    }

    func testChapterFetchReportsEachRequestForImportProgress() async {
        let entries = [
            AO3ChapterSplitter.NavigateEntry(
                title: "One", chapterPath: "/works/1/chapters/11", dateText: nil),
            AO3ChapterSplitter.NavigateEntry(
                title: "Two", chapterPath: "/works/1/chapters/12", dateText: nil),
        ]
        let chapterPage = """
        <html><body><div class="userstuff module"><p>Chapter text</p></div></body></html>
        """
        var reportedRequests: [Int] = []

        _ = await AO3ChapterSplitter.fetchChapterContents(
            entries: entries,
            waitBetweenRequests: {},
            fetchPage: { _ in chapterPage },
            didStartRequest: { reportedRequests.append($0) })

        XCTAssertEqual(reportedRequests, [1, 2])
    }

    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: parseNavigatePage

    func testParsesMultichapterNavigate() throws {
        let html = try fixture("ao3-navigate-multichapter")
        let entries = AO3ChapterSplitter.parseNavigatePage(html: html)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].title, "1. The Beginning")
        XCTAssertEqual(entries[0].chapterPath, "/works/12345/chapters/100001")
        XCTAssertEqual(entries[0].dateText, "2024-01-15")
    }

    func testParsesCJKTitle() throws {
        let html = try fixture("ao3-navigate-multichapter")
        let entries = AO3ChapterSplitter.parseNavigatePage(html: html)
        XCTAssertEqual(entries[1].title, "2. 中間的章節")
        XCTAssertEqual(entries[1].chapterPath, "/works/12345/chapters/100002")
    }

    func testParsesHTMLEntitiesInTitle() throws {
        let html = try fixture("ao3-navigate-multichapter")
        let entries = AO3ChapterSplitter.parseNavigatePage(html: html)
        XCTAssertEqual(entries[2].title, "3. The & End")
    }

    func testParsesSingleChapterNavigate() throws {
        let html = try fixture("ao3-navigate-single")
        let entries = AO3ChapterSplitter.parseNavigatePage(html: html)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Solo Chapter")
    }

    func testEmptyHTMLReturnsEmptyArray() {
        let entries = AO3ChapterSplitter.parseNavigatePage(html: "<html><body></body></html>")
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: extractChapterContent

    func testExtractsUserstuffContent() throws {
        let html = try fixture("ao3-chapter-content")
        let content = AO3ChapterSplitter.extractChapterContent(html: html)
        XCTAssertNotNil(content)
        XCTAssertTrue(content!.contains("First paragraph of the story."))
        XCTAssertTrue(content!.contains("<em>emphasis</em>"))
        XCTAssertTrue(content!.contains("<blockquote>"))
        XCTAssertTrue(content!.contains("<hr"))
    }

    func testExtractReturnsNilForNoUserstuff() {
        let html = "<html><body><p>No userstuff here</p></body></html>"
        XCTAssertNil(AO3ChapterSplitter.extractChapterContent(html: html))
    }

    func testExtractHandlesNestedDivs() {
        let html = """
        <div class="userstuff module" role="article">
          <p>Before</p>
          <div class="inner">Nested content</div>
          <p>After</p>
        </div>
        """
        let content = AO3ChapterSplitter.extractChapterContent(html: html)
        XCTAssertNotNil(content)
        XCTAssertTrue(content!.contains("Before"))
        XCTAssertTrue(content!.contains("Nested content"))
        XCTAssertTrue(content!.contains("After"))
    }
}
