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

    func testSplitsChaptersWhenOnlySomeTitlesAreHeadingStyled() throws {
        // Real-world Google Doc: 第一章/第四章 are Heading 2, 第二章/第三章 are plain
        // paragraphs. All four must import, not just the two heading-styled ones.
        let r = GoogleDocsChapterSplitter.split(html: try fixture("gdoc-mixed-headings"),
                                                docID: "MIX", docTitle: "Mixed")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章", "第二章", "第三章 🔥", "第四章"])
        XCTAssertTrue(r.chapters[0].contentHTML.contains("alpha one body"))
        XCTAssertFalse(r.chapters[0].contentHTML.contains("第二章"))
        XCTAssertFalse(r.chapters[0].contentHTML.contains("beta two body"))
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2, 3])
    }

    func testTitleWithMarkerCharInWordIsNotRejected() {
        let html = """
        <html><body>
        <p><span>第一章 開始</span></p><p><span>alpha body</span></p>
        <p><span>第二章 歡迎回家</span></p><p><span>beta body</span></p>
        <p><span>第三章 盛大開幕</span></p><p><span>gamma body</span></p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "MK", docTitle: "MK")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章 開始", "第二章 歡迎回家", "第三章 盛大開幕"])
        XCTAssertTrue(r.chapters[1].contentHTML.contains("beta body"))
        XCTAssertFalse(r.chapters[1].contentHTML.contains("第三章"))
    }

    func testTOCGridAndDuplicateTitlesProduceOrderedNonEmptyChapters() {
        let html = """
        <html><body>
        <table>
        <tr><td><p>第一章 甲</p></td><td><p>第三章 丙</p></td><td><p>第五章 戊</p></td></tr>
        <tr><td><p>第二章 乙</p></td><td><p>第四章 丁</p></td><td><p></p></td></tr>
        </table>
        <p>第一章 甲</p><p></p>
        <p>第一章 甲</p><p>alpha body</p>
        <p>第二章 乙</p><p>beta body</p>
        <p>第三章 丙</p><p>gamma body</p>
        <p>第四章 丁</p><p>delta body</p>
        <p>第五章 戊</p><p>epsilon body</p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "TG", docTitle: "TG")
        XCTAssertEqual(r.chapters.map(\.title),
                       ["第一章 甲", "第二章 乙", "第三章 丙", "第四章 丁", "第五章 戊"])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2, 3, 4])
        XCTAssertTrue(r.chapters[0].contentHTML.contains("alpha body"))
        XCTAssertFalse(r.chapters[0].contentHTML.contains("第二章"))
    }

    func testDuplicateTitleKeepsRichestOccurrence() {
        let html = """
        <html><body>
        <p>第一章 甲</p><p>this is the real and longer first chapter body</p>
        <p>第二章 乙</p><p>second body</p>
        <p>第一章 甲</p><p>x</p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "DUP", docTitle: "DUP")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章 甲", "第二章 乙"])
        XCTAssertTrue(r.chapters[0].contentHTML.contains("longer first chapter"))
    }

    func testTOCParagraphWithLineBreaksIsNotSplitIntoChapters() {
        // A table-of-contents row packs several entries with <br>. It must not be
        // mistaken for a chapter title (would create spurious chapters).
        let html = """
        <html><body>
        <h2>第一章</h2><p>a</p>
        <p>第二章<br>第三章</p>
        <h2>第四章</h2><p>d</p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "TOC", docTitle: "TOC")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章", "第四章"])
    }
}
