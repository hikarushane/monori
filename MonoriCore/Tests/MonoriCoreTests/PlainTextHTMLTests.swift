import XCTest
@testable import MonoriCore

final class PlainTextHTMLTests: XCTestCase {
    func testSplitsOnBlankLinesAndJoinsCJKSoftWrapsWithoutSpace() {
        let text = "第一行\n第二行\n\n\n  第二段  \r\n\r\n"
        XCTAssertEqual(PlainTextHTML.paragraphs(from: text), ["第一行第二行", "第二段"])
    }

    func testLatinSoftWrapsJoinWithOneSpace() {
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "one\ntwo\n\nthree"), ["one two", "three"])
    }

    func testMixedBoundaryUsesNoSpaceWhenEitherSideIsCJK() {
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "abc\n中文\n\nx"), ["abc中文", "x"])
        XCTAssertEqual(PlainTextHTML.paragraphs(from: "中文\nabc\n\nx"), ["中文abc", "x"])
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
}
