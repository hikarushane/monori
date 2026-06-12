import XCTest
import SwiftData
@testable import ChapterlyCore

@MainActor
final class LibraryStoreTests: XCTestCase {
    private var store: LibraryStore!

    override func setUp() async throws {
        store = try LibraryStore.inMemory()
    }

    private func payload(_ title: String, _ url: String, order: Int,
                         excerpt: String? = nil) -> ImporterChapterPayload {
        ImporterChapterPayload(title: title, url: url, visibleDateText: nil,
                               excerpt: excerpt,
                               creatorName: "ocean",
                               collectionName: "【更新中】焚心 The Burning Heart",
                               collectionURL: "https://www.patreon.com/collection/9999",
                               domOrder: order)
    }

    func testImportCreatesCollectionAndChapters() throws {
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let collections = try store.collections()
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections[0].title, "【更新中】焚心 The Burning Heart")
        XCTAssertEqual(collections[0].creatorName, "ocean")
        XCTAssertEqual(store.orderedChapters(of: collections[0]).map(\.title), ["4 愛", "5 脣瓣"])
    }

    func testReimportMergesWithoutDuplicates() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2/", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let chapters = store.orderedChapters(of: try store.collections()[0])
        XCTAssertEqual(chapters.map(\.title), ["4 愛", "5 脣瓣"])
    }

    func testImportPersistsExcerptAndReimportFillsMissing() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        var chapter = store.orderedChapters(of: try store.collections()[0])[0]
        XCTAssertNil(chapter.excerpt)
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0,
                                       excerpt: "卡片上的公開短摘要。")])
        chapter = store.orderedChapters(of: try store.collections()[0])[0]
        XCTAssertEqual(chapter.excerpt, "卡片上的公開短摘要。")
    }

    func testReverseDirectionFlipsReadingOrder() throws {
        try store.applyImport([
            payload("newest", "https://patreon.com/posts/n-3", order: 0),
            payload("oldest", "https://patreon.com/posts/o-1", order: 1)
        ])
        let collection = try store.collections()[0]
        collection.sortDirection = .newestToOldest
        XCTAssertEqual(store.orderedChapters(of: collection).map(\.title), ["oldest", "newest"])
    }

    func testNeighborsFollowStoryOrder() throws {
        // Patreon DOM order: newest first (order 0 = newest)
        try store.applyImport([
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 0),
            payload("4 愛", "https://patreon.com/posts/4-2", order: 1),
            payload("3", "https://patreon.com/posts/3-1", order: 2)
        ])
        let collection = try store.collections()[0]
        let chapters = store.orderedChapters(of: collection)
        let middle = chapters.first { $0.title == "4 愛" }!
        let n = store.neighbors(of: middle)
        // previous = older chapter, next = newer chapter
        XCTAssertEqual(n.previous?.title, "3")
        XCTAssertEqual(n.next?.title, "5 脣瓣")
    }

    func testProgressSavedByNormalizedURL() throws {
        try store.applyImport([payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 0)])
        store.setProgress(forPageURL: "https://www.patreon.com/posts/5-3?utm_source=share", progress: 0.6)
        let chapter = store.chapter(withPageURL: "https://patreon.com/posts/5-3/")
        XCTAssertEqual(chapter?.readingProgress ?? -1, 0.6, accuracy: 0.001)
        XCTAssertNotNil(chapter?.lastReadAt)
    }

    func testToggleBookmarkPersistsAndTogglesBack() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let chapter = store.orderedChapters(of: try store.collections()[0])[0]
        XCTAssertFalse(chapter.isBookmarked)

        store.toggleBookmark(chapter)
        // Re-fetch through the store to prove the change was saved, not just mutated in memory.
        XCTAssertEqual(store.chapter(withPageURL: chapter.urlString)?.isBookmarked, true)

        store.toggleBookmark(chapter)
        XCTAssertEqual(store.chapter(withPageURL: chapter.urlString)?.isBookmarked, false)
    }

    func testProgressSavedByMatchingPatreonPostIDWhenSlugChanges() throws {
        try store.applyImport([payload("Chapter", "https://patreon.com/posts/160628832", order: 0)])
        store.setProgress(forPageURL: "https://www.patreon.com/posts/chapter-title-160628832?utm_source=share",
                          progress: 0.4)
        let chapter = store.chapter(withPageURL: "https://patreon.com/posts/160628832")
        XCTAssertEqual(chapter?.readingProgress ?? -1, 0.4, accuracy: 0.001)
    }

    func testFooterScrollDoesNotOverwriteReadingProgress() throws {
        try store.applyImport([payload("Chapter", "https://patreon.com/posts/160628832", order: 0)])
        store.setProgress(forPageURL: "https://patreon.com/posts/160628832", progress: 0.5)
        store.setProgress(forPageURL: "https://patreon.com/posts/160628832", progress: 0.98)
        let chapter = store.chapter(withPageURL: "https://patreon.com/posts/160628832")
        XCTAssertEqual(chapter?.readingProgress ?? -1, 0.5, accuracy: 0.001)
    }

    func testManualAddRenameDelete() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let collection = try store.collections()[0]
        try store.addManualChapter(to: collection, title: "Extra",
                                   urlString: "https://patreon.com/posts/extra-9")
        let chapters = store.orderedChapters(of: collection)
        XCTAssertEqual(chapters.count, 2)
        store.rename(chapters[1], to: "Extra (fixed)")
        store.delete(chapters[0])
        let remaining = store.orderedChapters(of: collection)
        XCTAssertEqual(remaining.map(\.title), ["Extra (fixed)"])
    }

    func testClearLibraryRemovesEverything() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.clearLibrary()
        XCTAssertTrue(try store.collections().isEmpty)
    }

    func testNoChapterStoresBodyText() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let chapter = store.orderedChapters(of: try store.collections()[0])[0]
        XCTAssertLessThan(chapter.title.utf8.count, PayloadValidator.maxFieldLength + 1)
        XCTAssertLessThan(chapter.urlString.utf8.count, PayloadValidator.maxURLLength + 1)
    }
}
