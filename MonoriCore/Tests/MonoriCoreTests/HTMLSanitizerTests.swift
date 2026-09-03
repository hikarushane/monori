import XCTest
@testable import MonoriCore

final class HTMLSanitizerTests: XCTestCase {

    func testStripsActiveContentFromForumFloorBody() {
        let dirty = """
        <div><p onclick="steal()">正文</p><script>window.x = 1;</script><style>p{}</style>
        <iframe src="https://evil.example/"></iframe><object data="x"></object><embed src="y">
        <a href="javascript:alert(1)">link</a><img src="data:image/png;base64,AAAA">
        <meta http-equiv="refresh" content="0;url=https://evil.example/">
        <script src="https://evil.example/late.js"></div>
        """
        let clean = HTMLSanitizer.sanitize(dirty)
        XCTAssertTrue(clean.contains("正文"))
        XCTAssertTrue(clean.contains("link"))
        for needle in ["<script", "<style", "<iframe", "<object", "<embed", "<meta",
                       "onclick", "javascript:", "data:image", "evil.example/late.js"] {
            XCTAssertFalse(clean.lowercased().contains(needle), "must strip \(needle)")
        }
    }

    func testLeavesOrdinaryMarkupUntouched() {
        let html = "<p>第一段</p><blockquote>引文</blockquote>"
            + "<p><img src=\"/data/attachment/forum/a.png\" alt=\"圖\"></p>"
            + "<a href=\"https://waterfall.slashtw.space/thread/1\">link</a>"
        XCTAssertEqual(HTMLSanitizer.sanitize(html), html)
    }
}
