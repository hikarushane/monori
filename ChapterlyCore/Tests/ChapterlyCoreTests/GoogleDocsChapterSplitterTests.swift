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

    func testTitleWithTrailingSentencePunctuationIsStripped() {
        let html = """
        <html><body>
        <p><span>第一幕：擁抱。</span></p><p><span>act1 body text here</span></p>
        <p><span>第二幕：傳遞！</span></p><p><span>act2 body text here</span></p>
        <p><span>第三幕：吊襪帶？</span></p><p><span>act3 body text here</span></p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "SP", docTitle: "SP")
        XCTAssertEqual(r.chapters.map(\.title),
                       ["第一幕：擁抱", "第二幕：傳遞", "第三幕：吊襪帶"])
    }

    func testRealWorldTOCTableImportsInOrderWithContent() throws {
        let r = GoogleDocsChapterSplitter.split(html: try fixture("gdoc-toc-table"),
                                                docID: "EBF", docTitle: "Everyone's Best Friend")
        XCTAssertEqual(r.chapters.map(\.title),
                       ["第一章 一些新的東西開始", "第二章 不是小女孩", "第三章 唯一的希望",
                        "第四章 盛大開幕", "第五章 歡迎回家"])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2, 3, 4])
        XCTAssertTrue(r.chapters[0].contentHTML.contains("alpha body one"))
        XCTAssertTrue(r.chapters[4].contentHTML.contains("epsilon body five"))
        for chapter in r.chapters {
            XCTAssertFalse(chapter.contentHTML.contains("第三十五"),
                           "no chapter should leak another chapter's title")
        }
    }

    func testSpecialChaptersDetectedByTextPatternWithoutFontSize() {
        let html = """
        <html><body>
        <p><span>第一章 開始</span></p><p><span>chapter one body text</span></p>
        <p><span>特別篇一 模仿遊戲</span></p><p><span>special ep body text</span></p>
        <p><span>作者的信</span></p><p><span>author letter body text</span></p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "TP", docTitle: "TP")
        XCTAssertEqual(r.chapters.map(\.title),
                       ["第一章 開始", "特別篇一 模仿遊戲", "作者的信"])
    }

    func testTOCRowWithMultipleSpecialChaptersIsRejected() {
        let html = """
        <html><body>
        <p><span>特別篇一 模仿遊戲 特別篇二 趕上</span></p>
        <p><span>特別篇一 模仿遊戲</span></p><p><span>ep1 body</span></p>
        <p><span>特別篇二 趕上</span></p><p><span>ep2 body</span></p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "MR", docTitle: "MR")
        XCTAssertEqual(r.chapters.map(\.title), ["特別篇一 模仿遊戲", "特別篇二 趕上"])
    }

    func testRealWorldSpecialChaptersImportComplete() throws {
        let r = GoogleDocsChapterSplitter.split(html: try fixture("gdoc-special-chapters"),
                                                docID: "SC", docTitle: "Everyone's Best Friend")
        XCTAssertEqual(r.chapters.map(\.title), [
            "第四十九章 不同形式的空間",
            "作者的信",
            "特別篇一 模仿遊戲",
            "第一幕：擁抱",
            "第二幕：傳遞",
            "第三幕：吊襪帶",
            "特別篇二 趕上"
        ])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2, 3, 4, 5, 6])
        XCTAssertTrue(r.chapters[0].contentHTML.contains("ch49 body"))
        XCTAssertTrue(r.chapters[1].contentHTML.contains("author letter body"))
        XCTAssertTrue(r.chapters[2].contentHTML.contains("special ep1 intro"))
        XCTAssertTrue(r.chapters[3].contentHTML.contains("act1 body"))
        XCTAssertTrue(r.chapters[6].contentHTML.contains("special ep2 body"))
        // 幕 titles have trailing 。 stripped
        XCTAssertFalse(r.chapters[3].title.hasSuffix("。"))
        XCTAssertFalse(r.chapters[4].title.hasSuffix("。"))
        // No TOC table entries leaked as chapters
        for ch in r.chapters {
            XCTAssertFalse(ch.contentHTML.isEmpty, "\(ch.title) should have body content")
        }
    }

    func testLargeFontParagraphsDetectedAsChapters() {
        let html = """
        <html><body>
        <p><span style="font-size:26pt">第一章 開始</span></p>
        <p><span>chapter one body content here</span></p>
        <p><span style="font-size:26pt">作者的信</span></p>
        <p><span>letter body content here</span></p>
        <p><span style="font-size:26pt">特別篇一 模仿遊戲</span></p>
        <p><span>special episode body content here</span></p>
        </body></html>
        """
        let r = GoogleDocsChapterSplitter.split(html: html, docID: "LF", docTitle: "LF")
        XCTAssertEqual(r.chapters.map(\.title),
                       ["第一章 開始", "作者的信", "特別篇一 模仿遊戲"])
        XCTAssertTrue(r.chapters[0].contentHTML.contains("chapter one body"))
        XCTAssertTrue(r.chapters[1].contentHTML.contains("letter body"))
        XCTAssertTrue(r.chapters[2].contentHTML.contains("special episode body"))
    }
}
