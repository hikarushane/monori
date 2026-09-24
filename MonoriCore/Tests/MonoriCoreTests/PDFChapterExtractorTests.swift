import XCTest
import PDFKit
import CoreText
@testable import MonoriCore

final class PDFChapterExtractorTests: XCTestCase {
    /// One page per string, text drawn with CoreText so PDFKit can extract it.
    private func makePDF(pages: [String]) throws -> PDFDocument {
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let ctx = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        for text in pages {
            ctx.beginPDFPage(nil)
            let attr = NSAttributedString(string: text, attributes: [.font: font])
            let setter = CTFramesetterCreateWithAttributedString(attr)
            let path = CGPath(rect: box.insetBy(dx: 40, dy: 40), transform: nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return try XCTUnwrap(PDFDocument(data: data as Data))
    }

    private func addOutline(_ doc: PDFDocument, _ entries: [(String, Int)]) throws {
        let root = PDFOutline()
        for (i, (label, page)) in entries.enumerated() {
            let node = PDFOutline()
            node.label = label
            node.destination = PDFDestination(page: try XCTUnwrap(doc.page(at: page)), at: CGPoint(x: 0, y: 792))
            root.insertChild(node, at: i)
        }
        doc.outlineRoot = root
    }

    func testOutlineDrivesChaptersWithForeword() throws {
        let doc = try makePDF(pages: ["Preface text.", "Alpha begins.", "Alpha continues.", "Beta begins."])
        try addOutline(doc, [("Alpha", 1), ("Beta", 3)])
        let r = try PDFChapterExtractor.extract(document: doc, fileName: "book.pdf")
        XCTAssertEqual(r.sourceKind, .localFile)
        XCTAssertEqual(r.title, "book")
        XCTAssertEqual(r.chapters.map(\.title), ["前言", "Alpha", "Beta"])
        XCTAssertEqual(r.chapters.map(\.orderIndex), [0, 1, 2])
        XCTAssertTrue(r.chapters[1].contentHTML?.contains("Alpha begins.") ?? false)
        XCTAssertTrue(r.chapters[1].contentHTML?.contains("Alpha continues.") ?? false)
        XCTAssertFalse(r.chapters[1].contentHTML?.contains("Beta") ?? true)
        XCTAssertEqual(r.chapters[2].urlString, r.sourceURLString + "#2")
    }

    func testNoOutlineFallsBackToTextHeadings() throws {
        let doc = try makePDF(pages: ["Chapter 1\nOne.", "Chapter 2\nTwo."])
        let r = try PDFChapterExtractor.extract(document: doc, fileName: "flat.pdf")
        XCTAssertEqual(r.chapters.map(\.title), ["Chapter 1", "Chapter 2"])
        XCTAssertEqual(r.chapters[0].contentHTML, "<p>One.</p>")
    }

    func testNoOutlineNoHeadingsIsSingleChapter() throws {
        let doc = try makePDF(pages: ["Just prose.", "More prose."])
        let r = try PDFChapterExtractor.extract(document: doc, fileName: "flat.pdf")
        XCTAssertEqual(r.chapters.map(\.title), ["flat"])
        XCTAssertEqual(r.chapters[0].contentHTML, "<p>Just prose.</p>\n<p>More prose.</p>")
    }

    func testDocumentTitleAttributeWins() throws {
        let doc = try makePDF(pages: ["Body."])
        doc.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Real Title",
                                  PDFDocumentAttribute.authorAttribute: "Someone"]
        let r = try PDFChapterExtractor.extract(document: doc, fileName: "flat.pdf")
        XCTAssertEqual(r.title, "Real Title")
        XCTAssertEqual(r.creatorName, "Someone")
    }

    func testEmptyTextIsRejected() throws {
        let doc = try makePDF(pages: [" ", ""])
        XCTAssertThrowsError(try PDFChapterExtractor.extract(document: doc, fileName: "scan.pdf")) {
            XCTAssertEqual($0 as? LocalFileImportError, .pdfWithoutText)
        }
    }

    func testGarbageDataIsRejected() {
        XCTAssertThrowsError(try PDFChapterExtractor.extract(data: Data("nope".utf8), fileName: "x.pdf")) {
            XCTAssertEqual($0 as? LocalFileImportError, .unreadablePDF)
        }
        XCTAssertThrowsError(try PDFChapterExtractor.extract(data: Data(count: LocalFileIdentity.maxFileSize + 1), fileName: "x.pdf")) {
            XCTAssertEqual($0 as? LocalFileImportError, .fileTooLarge)
        }
    }
}
