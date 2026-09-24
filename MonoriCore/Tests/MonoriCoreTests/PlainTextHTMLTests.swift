import XCTest
@testable import MonoriCore

final class PlainTextHTMLTests: XCTestCase {
    func testSplitsOnBlankLinesAndJoinsSoftWraps() {
        let text = "第一行\n第二行\n\n\n  第二段  \r\n\r\n"
        XCTAssertEqual(PlainTextHTML.paragraphs(from: text), ["第一行 第二行", "第二段"])
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
