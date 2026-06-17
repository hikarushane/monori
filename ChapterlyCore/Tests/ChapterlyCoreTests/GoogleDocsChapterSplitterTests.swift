import XCTest
@testable import ChapterlyCore

final class GoogleDocsChapterSplitterTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testSplitsThreeChaptersWithCleanTitles() throws {
        let result = GoogleDocsChapterSplitter.split(html: try fixture("gdoc-33chapter"),
                                                     docID: "ABC", docTitle: "Undone by Time")
        XCTAssertEqual(result.chapters.map(\.title), ["第一章：A", "第二章：B", "第三章：C"])
        XCTAssertTrue(result.chapters[0].contentHTML.contains("body a1"))
        XCTAssertFalse(result.chapters[0].contentHTML.contains("第二章"))
        XCTAssertEqual(result.sourceURLString, "https://docs.google.com/document/d/ABC")
    }

    func testReadingOrderMapsToAscendingOrderIndex() throws {
        let r = GoogleDocsChapterSplitter.split(html: try fixture("gdoc-33chapter"),
                                                docID: "ABC", docTitle: "T")
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2])
        XCTAssertEqual(r.chapters[0].urlString, "https://docs.google.com/document/d/ABC#chapter-0")
    }

    func testDropsLeadingTOCHeading() throws {
        let r = GoogleDocsChapterSplitter.split(html: try fixture("gdoc-42chapter-toc"),
                                                docID: "D2", docTitle: "Behind the Script")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章：意外的角色", "第二章：試鏡"])
    }

    func testNoHeadingFallsBackToSingleChapter() throws {
        let r = GoogleDocsChapterSplitter.split(html: try fixture("gdoc-noheading"),
                                                docID: "D3", docTitle: "煙火")
        XCTAssertEqual(r.chapters.count, 1)
        XCTAssertEqual(r.chapters[0].title, "煙火")
        XCTAssertTrue(r.chapters[0].contentHTML.contains("line 1"))
    }

    func testStripsScriptStyleAndInlineHandlers() {
        let html = """
        <html><body>
        <h1>第一章</h1><p onclick="steal()">a</p><script>evil()</script>
        <h1>第二章</h1><style>.x{color:red}</style><p>b</p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "S", docTitle: "S")
        let joined = r.chapters.map(\.contentHTML).joined()
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("<style"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("onclick"))
        XCTAssertTrue(joined.contains("a"))
        XCTAssertTrue(joined.contains("b"))
    }

    func testSanitizeStripsJavascriptHrefsDataSrcAndMeta() {
        let dirty = """
        <a href="javascript:alert(1)">x</a>
        <a href='javascript:void(0)'>y</a>
        <img src="data:image/png;base64,ABC">
        <img src='data:text/html,<h1>hi</h1>'>
        <meta http-equiv="refresh" content="0;url=http://evil.com">
        <a href="https://safe.com">z</a>
        """
        let clean = GoogleDocsChapterSplitter.sanitize(dirty)
        XCTAssertFalse(clean.localizedCaseInsensitiveContains("javascript:"))
        XCTAssertFalse(clean.localizedCaseInsensitiveContains("data:"))
        XCTAssertFalse(clean.localizedCaseInsensitiveContains("<meta"))
        XCTAssertTrue(clean.contains("https://safe.com"))
        XCTAssertTrue(clean.contains(">x<"))
        XCTAssertTrue(clean.contains(">y<"))
    }
}
