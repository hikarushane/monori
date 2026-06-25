import XCTest
@testable import MonoriCore

@MainActor
final class GoogleDocsImportStoreTests: XCTestCase {
    private func imported(_ titles: [String]) -> ImportedCollection {
        let src = "https://docs.google.com/document/d/ABC"
        let chapters = titles.enumerated().map { i, t in
            ImportedChapter(title: t, urlString: "\(src)#chapter-\(i)",
                            orderIndex: i, contentHTML: "<p>\(t)</p>")
        }
        return ImportedCollection(sourceURLString: src, title: "Doc", creatorName: nil, chapters: chapters)
    }

    func testCreatesGoogleDocsCollectionWithContent() throws {
        let store = try LibraryStore.inMemory()
        try store.applyDocImport(imported(["第一章", "第二章", "第三章"]))
        let cols = try store.collections()
        XCTAssertEqual(cols.count, 1)
        XCTAssertEqual(cols[0].sourceKind, .googleDocs)
        XCTAssertEqual(cols[0].chapters.count, 3)
        XCTAssertTrue(cols[0].chapters.allSatisfy { $0.contentHTML != nil })
    }

    func testReadingOrderAndNeighbors() throws {
        let store = try LibraryStore.inMemory()
        try store.applyDocImport(imported(["第一章", "第二章", "第三章"]))
        let col = try store.collections()[0]
        let ordered = store.orderedChapters(of: col).map(\.title)
        XCTAssertEqual(ordered, ["第一章", "第二章", "第三章"])
        let ch2 = col.chapters.first { $0.title == "第二章" }!
        let (prev, next) = store.neighbors(of: ch2)
        XCTAssertEqual(prev?.title, "第一章")
        XCTAssertEqual(next?.title, "第三章")
    }

    func testReimportIsIdempotent() throws {
        let store = try LibraryStore.inMemory()
        try store.applyDocImport(imported(["第一章", "第二章"]))
        try store.applyDocImport(imported(["第一章", "第二章"]))
        XCTAssertEqual(try store.collections()[0].chapters.count, 2)
    }

    func testAO3ImportCreatesAO3Collection() throws {
        let store = try LibraryStore.inMemory()
        let imported = ImportedCollection(
            sourceURLString: "https://archiveofourown.org/works/12345",
            title: "Test Work",
            creatorName: "Author",
            sourceKind: .ao3,
            chapters: [
                ImportedChapter(title: "Chapter 1", urlString: "https://archiveofourown.org/works/12345/chapters/100001",
                                orderIndex: 0, contentHTML: "<p>Content</p>")
            ]
        )
        try store.applyDocImport(imported)
        let cols = try store.collections()
        XCTAssertEqual(cols.count, 1)
        XCTAssertEqual(cols[0].sourceKind, .ao3)
        XCTAssertEqual(cols[0].chapters.count, 1)
        XCTAssertTrue(cols[0].chapters[0].contentHTML != nil)
    }
}
