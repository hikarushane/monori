import XCTest
@testable import MonoriCore

final class TextChapterSplitterTests: XCTestCase {
    func testHeadingDetection() {
        XCTAssertTrue(TextChapterSplitter.isHeading("第一章 初遇"))
        XCTAssertTrue(TextChapterSplitter.isHeading("第一章初遇"))
        XCTAssertTrue(TextChapterSplitter.isHeading("第12回"))
        XCTAssertTrue(TextChapterSplitter.isHeading("第三節：夜"))
        XCTAssertTrue(TextChapterSplitter.isHeading("第一百二十三章 終"))
        XCTAssertTrue(TextChapterSplitter.isHeading("Chapter 1"))
        XCTAssertTrue(TextChapterSplitter.isHeading("CHAPTER 2: The Return"))
        XCTAssertTrue(TextChapterSplitter.isHeading("Ch. 3 - Dawn"))
        XCTAssertFalse(TextChapterSplitter.isHeading("第一章的內容其實很無聊。"))
        XCTAssertFalse(TextChapterSplitter.isHeading("Chapters are long"))
        XCTAssertFalse(TextChapterSplitter.isHeading("第一卷"))
        XCTAssertFalse(TextChapterSplitter.isHeading(String(repeating: "第一章", count: 14)))
    }

    func testSplitsChineseHeadingsWithForeword() {
        let text = """
        作者的話
        謝謝大家。

        第一章 初遇
        她走進房間。

        第二章  重逢
        他回頭。
        """
        let r = TextChapterSplitter.split(text: text, fileName: "小說.txt")
        XCTAssertEqual(r.sourceKind, .localFile)
        XCTAssertEqual(r.title, "小說")
        XCTAssertNil(r.creatorName)
        XCTAssertEqual(r.sourceURLString, LocalFileIdentity.sourceURLString(fileName: "小說.txt"))
        XCTAssertEqual(r.chapters.map(\.title), ["前言", "第一章 初遇", "第二章 重逢"])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2])
        XCTAssertEqual(r.chapters[1].urlString, r.sourceURLString + "#1")
        XCTAssertEqual(r.chapters[0].contentHTML, "<p>作者的話</p>\n<p>謝謝大家。</p>")
        XCTAssertEqual(r.chapters[1].contentHTML, "<p>她走進房間。</p>")
    }

    func testEnglishHeadingsWithoutForeword() {
        let text = "Chapter 1\n\nOnce.\n\nCh. 2\n\nTwice."
        let r = TextChapterSplitter.split(text: text, fileName: "novel.txt")
        XCTAssertEqual(r.chapters.map(\.title), ["Chapter 1", "Ch. 2"])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1])
    }

    func testNoHeadingsBecomesSingleChapterNamedAfterFile() {
        let r = TextChapterSplitter.split(text: "只有一段。\n\n再一段。", fileName: "story.txt")
        XCTAssertEqual(r.chapters.map(\.title), ["story"])
        XCTAssertEqual(r.chapters[0].contentHTML, "<p>只有一段。</p>\n<p>再一段。</p>")
    }

    func testConsecutiveHeadingsDropEmptyChapterAndReindex() {
        let text = "第一章\n第二章\n內容"
        let r = TextChapterSplitter.split(text: text, fileName: "x.txt")
        XCTAssertEqual(r.chapters.map(\.title), ["第二章"])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0])
    }

    func testEmptyTextYieldsNoChapters() {
        XCTAssertTrue(TextChapterSplitter.split(text: "  \n\n ", fileName: "e.txt").chapters.isEmpty)
    }

    func testOnePerLineFileKeepsEachLineAsParagraphInEveryChapter() {
        let text = "第一章\n甲。\n乙。\n第二章\n丙。"
        let r = TextChapterSplitter.split(text: text, fileName: "x.txt")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章", "第二章"])
        XCTAssertEqual(r.chapters[0].contentHTML, "<p>甲。</p>\n<p>乙。</p>")
        XCTAssertEqual(r.chapters[1].contentHTML, "<p>丙。</p>")
    }

    func testBlankLinesOnlyAroundHeadingsKeepsOneParagraphPerLine() {
        let text = "第一章 A\n\n段一。\n段二。\n段三。\n\n第二章 B\n\n段四。\n段五。"
        let r = TextChapterSplitter.split(text: text, fileName: "n.txt")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章 A", "第二章 B"])
        XCTAssertEqual(r.chapters[0].contentHTML, "<p>段一。</p>\n<p>段二。</p>\n<p>段三。</p>")
        XCTAssertEqual(r.chapters[1].contentHTML, "<p>段四。</p>\n<p>段五。</p>")
    }
}
