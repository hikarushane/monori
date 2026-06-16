import Foundation
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

    private func temporaryStoreURL() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL,
                                                withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return directoryURL.appendingPathComponent("Library.store")
    }

    private func onDiskStore(at storeURL: URL) throws -> LibraryStore {
        let config = ModelConfiguration("LibraryStoreTests", url: storeURL)
        let container = try ModelContainer(for: LocalCollectionModel.self, LocalChapterModel.self,
                                           configurations: config)
        return LibraryStore(container: container)
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
        XCTAssertEqual(store.orderedChapters(of: collection).map(\.title), ["newest", "oldest"])
    }

    func testReimportKeepsPublishOrderRegardlessOfScrapeDirection() throws {
        // Reproduces the field bug: a collection first imported up to ch14, then
        // refreshed once ch15-17 were posted. Patreon lists newest-first, so the
        // crawl sees ch17 before ch15 and the merger appends them as 17,16,15 after
        // ch14. Post IDs increase with publish time (intro oldest == smallest ID).
        func post(_ id: Int) -> String { "https://patreon.com/posts/c-\(id)" }
        func title(_ id: Int) -> String { id == 100 ? "人物介紹" : "守護著妳 \(id - 100)" }

        // First import: intro(100) + ch1(101)...ch14(114), crawled newest-first.
        let firstIDs = Array((100...114).reversed())            // 114,113,...,101,100
        try store.applyImport(firstIDs.enumerated().map { dom, id in
            payload(title(id), post(id), order: dom)
        })

        // Refresh: full list ch17(117)...intro(100), crawled newest-first.
        let secondIDs = Array((100...117).reversed())           // 117,...,100
        try store.applyImport(secondIDs.enumerated().map { dom, id in
            payload(title(id), post(id), order: dom)
        })

        let collection = try store.collections()[0]
        collection.sortDirection = .oldestToNewest

        // Default (oldest → newest) must be true publish order: intro, 1, 2, ... 17.
        let expected = ["人物介紹"] + (1...17).map { "守護著妳 \($0)" }
        XCTAssertEqual(store.orderedChapters(of: collection).map(\.title), expected)

        // ⇅ shows newest first.
        collection.sortDirection = .newestToOldest
        XCTAssertEqual(store.orderedChapters(of: collection).map(\.title), expected.reversed())

        // Neighbors follow publish order (previous == older, next == newer).
        func chapter(_ t: String) -> LocalChapterModel {
            store.orderedChapters(of: collection).first { $0.title == t }!
        }
        XCTAssertNil(store.neighbors(of: chapter("人物介紹")).previous)            // oldest: no 上一章
        XCTAssertEqual(store.neighbors(of: chapter("守護著妳 14")).next?.title,
                       "守護著妳 15")                                            // ch14 → 下一章 ch15
        XCTAssertNil(store.neighbors(of: chapter("守護著妳 17")).next)            // newest: no 下一章
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

    func testToggleBookmarkPersistsAndTogglesBack() throws {
        let storeURL = try temporaryStoreURL()
        var diskStore = try onDiskStore(at: storeURL)

        try diskStore.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let chapter = diskStore.orderedChapters(of: try diskStore.collections()[0])[0]
        let pageURL = chapter.urlString
        XCTAssertFalse(chapter.isBookmarked)

        diskStore.toggleBookmark(chapter)
        // Keep the original page URL re-fetch check, then verify across a fresh store boundary.
        XCTAssertEqual(diskStore.chapter(withPageURL: pageURL)?.isBookmarked, true)

        diskStore = try onDiskStore(at: storeURL)
        let reloadedBookmarkedChapter = try XCTUnwrap(diskStore.chapter(withPageURL: pageURL))
        XCTAssertTrue(reloadedBookmarkedChapter.isBookmarked)

        diskStore.toggleBookmark(reloadedBookmarkedChapter)
        XCTAssertEqual(diskStore.chapter(withPageURL: pageURL)?.isBookmarked, false)

        diskStore = try onDiskStore(at: storeURL)
        XCTAssertEqual(diskStore.chapter(withPageURL: pageURL)?.isBookmarked, false)
    }

    func testChapterLookupMatchesByPatreonPostIDWhenSlugChanges() throws {
        try store.applyImport([payload("Chapter", "https://patreon.com/posts/160628832", order: 0)])
        let chapter = store.chapter(
            withPageURL: "https://www.patreon.com/posts/chapter-title-160628832?utm_source=share")
        XCTAssertEqual(chapter?.title, "Chapter")
    }

    func testRenameAndDelete() throws {
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let collection = try store.collections()[0]
        let chapters = store.orderedChapters(of: collection)
        store.rename(chapters[1], to: "5 脣瓣 (fixed)")
        store.delete(chapters[0])
        let remaining = store.orderedChapters(of: collection)
        XCTAssertEqual(remaining.map(\.title), ["5 脣瓣 (fixed)"])
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
