import XCTest
@testable import MonoriCore

final class PlainTextHTMLTests: XCTestCase {
    func testCJKNewlineIsAParagraphBreak() {
        let text = "第一行\n第二行\n\n\n  第二段  \r\n\r\n"
        XCTAssertEqual(PlainTextHTML.paragraphs(from: text), ["第一行", "第二行", "第二段"])
    }

    func testLatinSoftWrapsJoinWithOneSpace() {
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "one\ntwo\n\nthree"), ["one two", "three"])
    }

    func testMixedBoundaryBreaksParagraphWhenEitherSideIsCJK() {
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "abc\n中文\n\nx"), ["abc", "中文", "x"])
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "中文\nabc\n\nx"), ["中文", "abc", "x"])
    }

    func testNoBlankLinesMeansOneParagraphPerLine() {
        let text = "\n　第一段。\n第二段。\n\tthird line\n\n"
        XCTAssertEqual(PlainTextHTML.paragraphs(from: text), ["第一段。", "第二段。", "third line"])
        XCTAssertEqual(PlainTextHTML.render(text: text), "<p>第一段。</p>\n<p>第二段。</p>\n<p>third line</p>")
    }

    func testRenderEscapesAndWraps() {
        XCTAssertEqual(PlainTextHTML.render(paragraphs: ["a < b & c", "\"q\""]),
                       "<p>a &lt; b &amp; c</p>\n<p>&quot;q&quot;</p>")
    }

    func testRenderTextDropsEmptyParagraphs() {
        XCTAssertEqual(PlainTextHTML.render(text: "\n\n   \n\nx\n\n"), "<p>x</p>")
        XCTAssertEqual(PlainTextHTML.render(text: "   "), "")
    }

    func testDetectLayout() {
        XCTAssertEqual(PlainTextHTML.detectLayout(of: "a\nb\n"), .onePerLine)
        XCTAssertEqual(PlainTextHTML.detectLayout(of: "\n\na\n\nb\n\n"), .blankLineSeparated)
        XCTAssertEqual(PlainTextHTML.detectLayout(of: ""), .onePerLine)
    }

    func testExplicitLayoutOverridesDetection() {
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "a\nb", layout: .blankLineSeparated), ["a b"])
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "a\n\nb", layout: .onePerLine), ["a", "b"])
        XCTAssertEqual(PlainTextHTML.render(text: "甲\n乙", layout: .blankLineSeparated), "<p>甲</p>\n<p>乙</p>")
    }

    func testChineseNovelWithBlankLinesOnlyAroundHeadingsKeepsParagraphs() {
        let text = "段一。\n段二。\n段三。\n\n第二章 B\n\n段四。\n段五。"
        XCTAssertEqual(PlainTextHTML.paragraphs(from: text, layout: .blankLineSeparated),
                       ["段一。", "段二。", "段三。", "第二章 B", "段四。", "段五。"])
    }
}
