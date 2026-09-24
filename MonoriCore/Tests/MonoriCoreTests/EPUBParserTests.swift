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
}
