import XCTest
@testable import MonoriCore

final class EPUBParserTests: XCTestCase {
    private func fixture(_ name: String, ext: String = "epub") throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext))
        return try Data(contentsOf: url)
    }

    // MARK: Core (Task 5)

    func testNoTOCUsesSpineOrderAndTitleFallbacks() throws {
        let r = try EPUBParser.parse(data: try fixture("local-epub-no-toc"), fileName: "plain.epub")
        XCTAssertEqual(r.sourceKind, .localFile)
        XCTAssertEqual(r.title, "plain")          // no dc:title → file name
        XCTAssertNil(r.creatorName)
        XCTAssertEqual(r.sourceURLString, LocalFileIdentity.sourceURLString(fileName: "plain.epub"))
        XCTAssertEqual(r.chapters.map(\.title), ["有標題", "用 H2", "第 3 章"])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2])
        XCTAssertEqual(r.chapters[2].urlString, r.sourceURLString + "#2")
        XCTAssertEqual(r.chapters[0].contentHTML?.trimmingCharacters(in: .whitespacesAndNewlines), "<p>一</p>")
    }

    func testStripMediaRemovesImagesSvgAndExternalLinksButKeepsText() {
        let html = ##"<p>a</p><img src="x.png"/><svg><rect/></svg><picture><source/><img src="y"/></picture><p><a href="https://e.com">out</a> <a href="#f">in</a></p><link rel="stylesheet" href="s.css"/>"##
        XCTAssertEqual(EPUBParser.stripMedia(html), ##"<p>a</p><p>out <a href="#f">in</a></p>"##)
    }

    func testStripMediaUnwrapsSingleQuotedAndUnquotedExternalLinks() {
        let html = ##"<p><a href='https://e.com'>out2</a> <a href=https://e.com>out3</a> <a class="x" href='mailto:a@e.com'>out4</a> <a HREF=http://e.com/p?q=1 title="t">out5</a> <a href='#f'>in</a></p>"##
        XCTAssertEqual(EPUBParser.stripMedia(html), ##"<p>out2 out3 out4 out5 <a href='#f'>in</a></p>"##)
    }

    func testBodyAndTitleHelpers() {
        XCTAssertEqual(EPUBParser.bodyHTML(of: "<html><BODY class=\"x\"> <p>b</p> </BODY></html>"), " <p>b</p> ")
        XCTAssertNil(EPUBParser.bodyHTML(of: "<p>no body</p>"))
        XCTAssertEqual(EPUBParser.chapterTitle(of: "<head><title> T </title></head><body><h1>H</h1></body>"), "T")
        XCTAssertEqual(EPUBParser.chapterTitle(of: "<body><h3 id=\"a\">H <b>3</b></h3></body>"), "H 3")
        XCTAssertNil(EPUBParser.chapterTitle(of: "<body><p>x</p></body>"))
    }

    func testRejectsNonZipMissingContainerAndDRM() throws {
        XCTAssertThrowsError(try EPUBParser.parse(data: Data("hello".utf8), fileName: "a.epub")) {
            XCTAssertEqual($0 as? LocalFileImportError, .notAnEPUB)
        }
        XCTAssertThrowsError(try EPUBParser.parse(data: try fixture("local-epub-no-container", ext: "zip"), fileName: "a.epub")) {
            XCTAssertEqual($0 as? LocalFileImportError, .notAnEPUB)
        }
        XCTAssertThrowsError(try EPUBParser.parse(data: try fixture("local-epub-encrypted"), fileName: "a.epub")) {
            XCTAssertEqual($0 as? LocalFileImportError, .drmProtected)
        }
    }

    func testRejectsOversizedData() {
        let big = Data(count: LocalFileIdentity.maxFileSize + 1)
        XCTAssertThrowsError(try EPUBParser.parse(data: big, fileName: "big.epub")) {
            XCTAssertEqual($0 as? LocalFileImportError, .fileTooLarge)
        }
    }

    // MARK: TOC and rejections (Task 6)

    func testEPUB3NavTOCBuildsChaptersAndSkipsNonLinearAndNav() throws {
        let r = try EPUBParser.parse(data: try fixture("local-epub3-nav"), fileName: "x.epub")
        XCTAssertEqual(r.title, "山與海")
        XCTAssertEqual(r.creatorName, "林作者")
        XCTAssertEqual(r.chapters.map(\.title), ["第一章 山", "第二章 海", "第三章 歸"])
        let c1 = try XCTUnwrap(r.chapters[0].contentHTML)
        XCTAssertTrue(c1.contains("山很高"))
        XCTAssertFalse(c1.contains("<img"))
        XCTAssertFalse(c1.contains("<script"))
        XCTAssertFalse(c1.contains("封面頁文字"))
        let c2 = try XCTUnwrap(r.chapters[1].contentHTML)
        XCTAssertTrue(c2.contains("海很深") && c2.contains("海的尾聲"))
        let c3 = try XCTUnwrap(r.chapters[2].contentHTML)
        XCTAssertTrue(c3.contains("外部連結"))
        XCTAssertFalse(c3.contains("https://example.com"))
        // Regression fixture: event handlers in an imported EPUB must not survive to the reader.
        XCTAssertTrue(c3.contains("回家"))
        XCTAssertFalse(c3.lowercased().contains("ontoggle"))
        XCTAssertFalse(c3.lowercased().contains("onclick"))
    }

    func testEPUB2NCXTOC() throws {
        let r = try EPUBParser.parse(data: try fixture("local-epub2-ncx"), fileName: "y.epub")
        XCTAssertEqual(r.title, "舊書")
        // Nested navPoint pointing at a.xhtml#s1 is a duplicate of 甲 and is dropped;
        // the pageList target must not become a chapter; c.xhtml folds into 乙.
        XCTAssertEqual(r.chapters.map(\.title), ["甲", "乙"])
        let c2 = try XCTUnwrap(r.chapters[1].contentHTML)
        XCTAssertTrue(c2.contains("乙的內容") && c2.contains("乙的續篇"))
        XCTAssertFalse(r.chapters.contains { $0.title == "9" || $0.title == "甲之一" })
    }
}
