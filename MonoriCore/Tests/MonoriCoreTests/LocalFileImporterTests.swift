import XCTest
@testable import MonoriCore

@MainActor
final class LocalFileImporterTests: XCTestCase {
    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext))
        return try Data(contentsOf: url)
    }

    func testFileTypeResolution() {
        XCTAssertEqual(LocalFileImporter.fileType(fileName: "a.PDF", typeIdentifier: nil), .pdf)
        XCTAssertEqual(LocalFileImporter.fileType(fileName: "a.epub", typeIdentifier: nil), .epub)
        XCTAssertEqual(LocalFileImporter.fileType(fileName: "a.txt", typeIdentifier: nil), .text)
        XCTAssertEqual(LocalFileImporter.fileType(fileName: "noext", typeIdentifier: "public.plain-text"), .text)
        XCTAssertEqual(LocalFileImporter.fileType(fileName: "noext", typeIdentifier: "com.adobe.pdf"), .pdf)
        XCTAssertEqual(LocalFileImporter.fileType(fileName: "noext", typeIdentifier: "org.idpf.epub-container"), .epub)
        XCTAssertNil(LocalFileImporter.fileType(fileName: "a.mobi", typeIdentifier: "public.data"))
    }

    func testTextRouteDecodesBig5AndSplits() throws {
        let r = try LocalFileImporter.importFile(data: try fixture("local-big5", ext: "txt"),
                                                 fileName: "big5.txt", typeIdentifier: nil)
        XCTAssertEqual(r.sourceKind, .localFile)
        XCTAssertEqual(r.chapters.map(\.title), ["第一章 開始"])
    }

    func testEPUBRoute() throws {
        let r = try LocalFileImporter.importFile(data: try fixture("local-epub2-ncx", ext: "epub"),
                                                 fileName: "b.epub", typeIdentifier: nil)
        XCTAssertEqual(r.chapters.map(\.title), ["甲", "乙"])
    }

    func testRejections() {
        XCTAssertThrowsError(try LocalFileImporter.importFile(data: Data("x".utf8), fileName: "a.mobi", typeIdentifier: nil)) {
            XCTAssertEqual($0 as? LocalFileImportError, .unsupportedType)
        }
        XCTAssertThrowsError(try LocalFileImporter.importFile(data: Data(count: LocalFileIdentity.maxFileSize + 1), fileName: "a.txt", typeIdentifier: nil)) {
            XCTAssertEqual($0 as? LocalFileImportError, .fileTooLarge)
        }
        XCTAssertThrowsError(try LocalFileImporter.importFile(data: Data([0x80, 0xFF, 0x80, 0xFF, 0x81, 0x00, 0xFE]), fileName: "a.txt", typeIdentifier: nil)) {
            XCTAssertEqual($0 as? LocalFileImportError, .undecodableText)
        }
        XCTAssertThrowsError(try LocalFileImporter.importFile(data: Data("   ".utf8), fileName: "a.txt", typeIdentifier: nil)) {
            XCTAssertEqual($0 as? LocalFileImportError, .noChapters)
        }
    }

    func testReimportSameFileNameMergesAndUpdatesContent() throws {
        let store = try LibraryStore.inMemory()
        let first = try LocalFileImporter.importFile(data: Data("第一章 A\n\n舊內容".utf8), fileName: "n.txt", typeIdentifier: nil)
        try store.applyDocImport(first)
        let second = try LocalFileImporter.importFile(data: Data("第一章 A\n\n新內容\n\n第二章 B\n\n二".utf8), fileName: "n.txt", typeIdentifier: nil)
        try store.applyDocImport(second)
        let cols = try store.collections()
        XCTAssertEqual(cols.count, 1)
        XCTAssertEqual(cols[0].sourceKind, .localFile)
        let ordered = store.orderedChapters(of: cols[0])
        XCTAssertEqual(ordered.map(\.title), ["第一章 A", "第二章 B"])
        XCTAssertEqual(ordered[0].contentHTML, "<p>新內容</p>")
    }
}
