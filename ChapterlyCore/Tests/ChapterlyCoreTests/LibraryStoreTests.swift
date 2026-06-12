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
