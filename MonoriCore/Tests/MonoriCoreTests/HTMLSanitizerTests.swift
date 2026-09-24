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

    // MARK: - EPUB-import probes (final-review finding): each survived sanitize() before hardening.

    func testStripsUnquotedEventHandler() {
        let clean = HTMLSanitizer.sanitize("<p onclick=alert(1)>x</p>")
        XCTAssertFalse(clean.lowercased().contains("onclick"))
        XCTAssertFalse(clean.contains("alert(1)"))
        XCTAssertTrue(clean.contains("<p") && clean.contains(">x</p>"))
    }

    func testStripsAutoFiringOntoggleThatReachesMessageHandler() {
        let clean = HTMLSanitizer.sanitize(
            "<details open ontoggle=window.webkit.messageHandlers.monoriImport.postMessage({})>y</details>")
        XCTAssertFalse(clean.lowercased().contains("ontoggle"))
        XCTAssertFalse(clean.contains("messageHandlers"))
        XCTAssertTrue(clean.contains("y"))
        XCTAssertTrue(clean.contains("<details"))
    }

    func testRemovesUnquotedJavascriptHref() {
        let clean = HTMLSanitizer.sanitize("<a href=javascript:alert(1)>z</a>")
        XCTAssertFalse(clean.lowercased().contains("javascript:"))
        XCTAssertTrue(clean.contains("z"))
    }

    func testRemovesObfuscatedDangerousSchemes() {
        for dirty in ["<a href=\"java\tscript:alert(1)\">a</a>",
                      "<a href=\" JavaScript:alert(1)\">a</a>",
                      "<a href='vbscript:msgbox(1)'>a</a>",
                      "<a xlink:href=\"javascript:alert(1)\">a</a>",
                      "<button formaction=javascript:alert(1)>a</button>",
                      "<img src=data:image/svg+xml;base64,AAAA>a"] {
            let clean = HTMLSanitizer.sanitize(dirty).lowercased()
            for needle in ["script:", "data:", "alert", "msgbox"] {
                XCTAssertFalse(clean.contains(needle), "\(dirty) must lose \(needle), got \(clean)")
            }
            XCTAssertTrue(clean.contains("a"))
        }
    }

    func testStripsHandlerAfterSlashSeparator() {
        let clean = HTMLSanitizer.sanitize("<p/onmouseover=\"alert(1)\">w</p>")
        XCTAssertFalse(clean.lowercased().contains("onmouseover"))
        XCTAssertTrue(clean.contains("w"))
    }

    func testStripsHandlerDirectlyAfterQuotedValueAndRejoinedHandlers() {
        for dirty in ["<p title=\"t\"onclick=alert(1)>w</p>",
                      "<p title='t'onclick=alert(1)>w</p>",
                      "<p  onclick=\"a\"onmouseover=alert(1)>w</p>"] {
            let clean = HTMLSanitizer.sanitize(dirty).lowercased()
            XCTAssertFalse(clean.contains("onclick") || clean.contains("onmouseover"), clean)
            XCTAssertFalse(clean.contains("alert"), clean)
            XCTAssertTrue(clean.contains("w"))
        }
    }

    func testRemovesBaseAndMetaHttpEquiv() {
        let clean = HTMLSanitizer.sanitize(
            "<base href=\"https://e.com/\"><BASE href=https://e.com/><meta http-equiv=refresh content=0><p>v</p>")
        XCTAssertFalse(clean.lowercased().contains("<base"))
        XCTAssertFalse(clean.lowercased().contains("http-equiv"))
        XCTAssertFalse(clean.contains("e.com"))
        XCTAssertTrue(clean.contains("<p>v</p>"))
    }

    func testRemovesStyleWithRemoteLoadsButKeepsPlainStyle() {
        let clean = HTMLSanitizer.sanitize(
            "<p style=\"background:url(x)\">a</p><p style='x:expression(alert(1))'>b</p>"
            + "<p style=\"@import 'y'\">c</p><p style=\"color:red\">d</p>")
        let lower = clean.lowercased()
        XCTAssertFalse(lower.contains("url("))
        XCTAssertFalse(lower.contains("expression("))
        XCTAssertFalse(lower.contains("@import"))
        XCTAssertTrue(clean.contains("<p style=\"color:red\">d</p>"))
        for text in ["a", "b", "c"] { XCTAssertTrue(clean.contains(">\(text)</p>")) }
    }

    func testKeepsSafeHrefsAndOnPrefixedWordsInText() {
        let html = "<p><a href=\"https://ok.example/a\">ok</a> <a href=\"#frag\">f</a>"
            + " <a href='https://ok.example/b'>b</a> honor=2 data: javascript: text</p>"
        XCTAssertEqual(HTMLSanitizer.sanitize(html), html)
    }
}
