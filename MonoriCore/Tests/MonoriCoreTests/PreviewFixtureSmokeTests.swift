import XCTest
import SwiftData
@testable import MonoriCore

@MainActor
final class PreviewFixtureSmokeTests: XCTestCase {

    func testEmptyStoreHasNoCollections() throws {
        let store = try LibraryStore.inMemory()
        XCTAssertEqual(try store.collectionCount(), 0)
        XCTAssertTrue(try store.collections().isEmpty)
    }

    func testSeededStoreHasCollectionsAndChapters() throws {
        let store = try LibraryStore.inMemory()
        let ctx = store.container.mainContext

        let collection = LocalCollectionModel(
            title: "Preview test collection",
            sourceURLString: "https://www.patreon.com/collection/fixture",
            creatorName: "fixture-author",
            sourceKind: .patreon)
        ctx.insert(collection)

        for i in 0..<3 {
            let ch = LocalChapterModel(
                title: "Chapter \(i + 1)",
                urlString: "https://www.patreon.com/posts/\(9000 + i)",
                orderIndex: i)
            ch.collection = collection
            ctx.insert(ch)
        }
        try ctx.save()

        XCTAssertEqual(try store.collectionCount(), 1)
        let fetched = try store.collections()
        XCTAssertEqual(fetched.first?.title, "Preview test collection")
        XCTAssertEqual(fetched.first?.chapters.count, 3)
        XCTAssertEqual(fetched.first?.sourceKind, .patreon)
        XCTAssertEqual(fetched.first?.creatorName, "fixture-author")
    }

    func testUnreadChaptersAreCountable() throws {
        let store = try LibraryStore.inMemory()
        let ctx = store.container.mainContext

        let collection = LocalCollectionModel(
            title: "Unread fixture",
            sourceURLString: "https://archiveofourown.org/works/fixture",
            creatorName: "writer",
            sourceKind: .ao3)
        collection.lastNewChapterAt = Date()
        ctx.insert(collection)

        for i in 0..<5 {
            let ch = LocalChapterModel(
                title: "Ch \(i + 1)",
                urlString: "https://archiveofourown.org/works/fixture/chapters/\(i)",
                orderIndex: i)
            ch.isNew = i >= 3
            ch.collection = collection
            ctx.insert(ch)
        }
        try ctx.save()

        let fetched = try store.collections().first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.unreadCount, 2)
        XCTAssertNotNil(fetched?.lastNewChapterAt)
    }

    func testAllSourceKindsCanBeSeedeed() throws {
        let store = try LibraryStore.inMemory()
        let ctx = store.container.mainContext

        for kind in SourceKind.allCases {
            let c = LocalCollectionModel(
                title: "Source: \(kind.rawValue)",
                sourceURLString: "https://example.com/\(kind.rawValue)/fixture",
                creatorName: kind == .googleDocs ? nil : "author",
                sourceKind: kind)
            ctx.insert(c)
            let ch = LocalChapterModel(
                title: "Chapter 1",
                urlString: "https://example.com/\(kind.rawValue)/ch/0",
                orderIndex: 0)
            ch.collection = c
            ctx.insert(ch)
        }
        try ctx.save()

        XCTAssertEqual(try store.collectionCount(), SourceKind.allCases.count)
    }

    func testBookmarkAndOptionalFieldsSeed() throws {
        let store = try LibraryStore.inMemory()
        let ctx = store.container.mainContext

        let c = LocalCollectionModel(
            title: "Bookmark test",
            sourceURLString: "https://example.com/bookmark/fixture",
            sourceKind: .vocus)
        c.readingStatus = .finished
        ctx.insert(c)

        let ch = LocalChapterModel(
            title: "Ch 1",
            urlString: "https://example.com/bookmark/ch/0",
            orderIndex: 0)
        ch.isBookmarked = true
        ch.contentHTML = "<p>stored</p>"
        ch.collection = c
        ctx.insert(ch)
        try ctx.save()

        let fetched = try store.collections().first
        XCTAssertEqual(fetched?.readingStatus, .finished)
        let chapter = fetched?.chapters.first
        XCTAssertEqual(chapter?.isBookmarked, true)
        XCTAssertNotNil(chapter?.contentHTML)
    }
}
