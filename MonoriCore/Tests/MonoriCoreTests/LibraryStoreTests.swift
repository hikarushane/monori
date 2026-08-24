import Foundation
import XCTest
import SwiftData
@testable import MonoriCore

@MainActor
final class LibraryStoreTests: XCTestCase {
    private var store: LibraryStore!

    override func setUp() async throws {
        store = try LibraryStore.inMemory()
    }

    private func payload(_ title: String, _ url: String, order: Int,
                         excerpt: String? = nil,
                         collection: String = "【更新中】焚心 The Burning Heart") -> ImporterChapterPayload {
        ImporterChapterPayload(title: title, url: url, visibleDateText: nil,
                               excerpt: excerpt,
                               creatorName: "ocean",
                               collectionName: collection,
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

    func testReimportRefreshesStaleCollectionTitle() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0,
                                       collection: "Customize this collection")])
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let collections = try store.collections()
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections[0].title, "【更新中】焚心 The Burning Heart")
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

    func testToggleBookmarkClearsSiblingsInSameCollection() throws {
        try store.applyImport([
            payload("Ch1", "https://patreon.com/posts/1-1", order: 0),
            payload("Ch2", "https://patreon.com/posts/2-2", order: 1),
            payload("Ch3", "https://patreon.com/posts/3-3", order: 2)
        ])
        let chapters = store.orderedChapters(of: try store.collections()[0])
        let ch1 = chapters[0], ch2 = chapters[1], ch3 = chapters[2]

        store.toggleBookmark(ch1)
        XCTAssertTrue(ch1.isBookmarked)

        store.toggleBookmark(ch2)
        XCTAssertTrue(ch2.isBookmarked)
        XCTAssertFalse(ch1.isBookmarked, "old bookmark should be cleared")

        store.toggleBookmark(ch3)
        XCTAssertTrue(ch3.isBookmarked)
        XCTAssertFalse(ch1.isBookmarked)
        XCTAssertFalse(ch2.isBookmarked)
    }

    func testUnbookmarkDoesNotAffectSiblings() throws {
        try store.applyImport([
            payload("Ch1", "https://patreon.com/posts/1-1", order: 0),
            payload("Ch2", "https://patreon.com/posts/2-2", order: 1)
        ])
        let chapters = store.orderedChapters(of: try store.collections()[0])
        let ch1 = chapters[0], ch2 = chapters[1]

        store.toggleBookmark(ch1)
        XCTAssertTrue(ch1.isBookmarked)

        // Unbookmark ch1
        store.toggleBookmark(ch1)
        XCTAssertFalse(ch1.isBookmarked)
        XCTAssertFalse(ch2.isBookmarked, "sibling should stay unchanged")
    }

    func testBookmarkInOneCollectionDoesNotAffectAnother() throws {
        try store.applyImport([payload("A-ch1", "https://patreon.com/posts/a-1", order: 0,
                                       collection: "Collection A")])
        // Second collection needs a different collectionURL
        let bPayload = ImporterChapterPayload(
            title: "B-ch1", url: "https://patreon.com/posts/b-1",
            visibleDateText: nil, excerpt: nil, creatorName: "author",
            collectionName: "Collection B",
            collectionURL: "https://www.patreon.com/collection/8888",
            domOrder: 0)
        try store.applyImport([bPayload])

        let collections = try store.collections()
        let colA = collections.first { $0.title == "Collection A" }!
        let colB = collections.first { $0.title == "Collection B" }!
        let chA = store.orderedChapters(of: colA)[0]
        let chB = store.orderedChapters(of: colB)[0]

        store.toggleBookmark(chA)
        store.toggleBookmark(chB)
        XCTAssertTrue(chA.isBookmarked, "different collection — must stay bookmarked")
        XCTAssertTrue(chB.isBookmarked)
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

    func testChapterWithVocusArticleURL() throws {
        let store = try LibraryStore.inMemory()
        let imported = ImportedCollection(
            sourceURLString: "https://vocus.cc/salon/TestSalon/room/aabbccdd11223344aabbccdd",
            title: "Test Room",
            creatorName: "Author",
            sourceKind: .vocus,
            chapters: [
                ImportedChapter(title: "First Article",
                                urlString: "https://vocus.cc/article/67ca7699fd897800017f312c",
                                orderIndex: 0),
                ImportedChapter(title: "Second Article",
                                urlString: "https://vocus.cc/article/67ca7699fd897800017f312d",
                                orderIndex: 1)
            ])
        try store.applyDocImport(imported)

        // Exact URL match
        let found = store.chapter(withPageURL: "https://vocus.cc/article/67ca7699fd897800017f312c")
        XCTAssertEqual(found?.title, "First Article")

        // With query params (web view may add tracking)
        let withQuery = store.chapter(withPageURL: "https://vocus.cc/article/67ca7699fd897800017f312c?from=salon")
        XCTAssertEqual(withQuery?.title, "First Article")

        // Non-existent article
        let missing = store.chapter(withPageURL: "https://vocus.cc/article/000000000000000000000000")
        XCTAssertNil(missing)

        // Patreon URL still returns nil (no Vocus match)
        let patreon = store.chapter(withPageURL: "https://www.patreon.com/posts/12345")
        XCTAssertNil(patreon)
    }

    func testChapterWithAFFChapterURL() throws {
        let store = try LibraryStore.inMemory()
        let imported = ImportedCollection(
            sourceURLString: "https://www.asianfanfics.com/story/view/1695131",
            title: "Test Story",
            creatorName: "Author",
            sourceKind: .asianFanfics,
            chapters: [
                ImportedChapter(title: "Chapter 1",
                                urlString: "https://www.asianfanfics.com/story/view/1695131/1",
                                orderIndex: 0),
                ImportedChapter(title: "Chapter 2",
                                urlString: "https://www.asianfanfics.com/story/view/1695131/2",
                                orderIndex: 1)
            ])
        try store.applyDocImport(imported)

        // Exact canonical URL match
        let exact = store.chapter(withPageURL: "https://www.asianfanfics.com/story/view/1695131/1")
        XCTAssertEqual(exact?.title, "Chapter 1")

        // Slug-suffixed URL (browser strips slug) should still resolve
        let withSlug = store.chapter(withPageURL: "https://www.asianfanfics.com/story/view/1695131/1/n-a")
        XCTAssertEqual(withSlug?.title, "Chapter 1")

        // Second chapter
        let second = store.chapter(withPageURL: "https://www.asianfanfics.com/story/view/1695131/2/chapter-title")
        XCTAssertEqual(second?.title, "Chapter 2")

        // Foreword URL returns nil
        let foreword = store.chapter(withPageURL: "https://www.asianfanfics.com/story/view/1695131")
        XCTAssertNil(foreword)

        // Non-existent chapter returns nil
        let missing = store.chapter(withPageURL: "https://www.asianfanfics.com/story/view/1695131/99")
        XCTAssertNil(missing)
    }

    func testChapterWithPageURLMatchesAO3Chapter() throws {
        let store = try LibraryStore.inMemory()
        let imported = ImportedCollection(
            sourceURLString: "https://archiveofourown.org/works/90528001",
            title: "Test Work",
            creatorName: "Author",
            sourceKind: .ao3,
            chapters: [
                ImportedChapter(title: "Chapter 1",
                                urlString: "https://archiveofourown.org/works/90528001/chapters/240725581",
                                orderIndex: 0),
                ImportedChapter(title: "Chapter 2",
                                urlString: "https://archiveofourown.org/works/90528001/chapters/240725582",
                                orderIndex: 1)
            ])
        try store.applyDocImport(imported)

        // Exact canonical URL match
        let exact = store.chapter(withPageURL: "https://archiveofourown.org/works/90528001/chapters/240725581")
        XCTAssertEqual(exact?.title, "Chapter 1")

        // URL with query and fragment (e.g. adult-content interstitial) should still resolve
        let withQuery = store.chapter(
            withPageURL: "https://archiveofourown.org/works/90528001/chapters/240725581?view_adult=true#comments")
        XCTAssertEqual(withQuery?.title, "Chapter 1")

        // Second chapter
        let second = store.chapter(withPageURL: "https://archiveofourown.org/works/90528001/chapters/240725582")
        XCTAssertEqual(second?.title, "Chapter 2")

        // Non-existent chapter returns nil
        let missing = store.chapter(withPageURL: "https://archiveofourown.org/works/90528001/chapters/000000")
        XCTAssertNil(missing)
    }

    func testChapterWithPageURLMatchesLegacyNonCanonicalAO3ChapterURL() throws {
        let store = try LibraryStore.inMemory()
        let imported = ImportedCollection(
            sourceURLString: "https://archiveofourown.org/works/90528001",
            title: "Test Work",
            creatorName: "Author",
            sourceKind: .ao3,
            chapters: [
                ImportedChapter(
                    title: "Legacy Chapter",
                    urlString: "https://www.archiveofourown.org/works/90528001/chapters/240725581?view_adult=true#comments",
                    orderIndex: 0)
            ])
        try store.applyDocImport(imported)

        let chapter = store.chapter(
            withPageURL: "https://archiveofourown.org/works/90528001/chapters/240725581")

        XCTAssertEqual(chapter?.title, "Legacy Chapter")
    }

    func testSaveAndRestoreReadingProgress() throws {
        let storeURL = try temporaryStoreURL()
        let diskStore = try onDiskStore(at: storeURL)

        try diskStore.applyImport([payload("Ch 1", "https://patreon.com/posts/1-100", order: 0)])
        let chapter = diskStore.orderedChapters(of: try diskStore.collections()[0])[0]

        XCTAssertNil(chapter.readingProgress)

        diskStore.saveReadingProgress(0.42, for: chapter)
        XCTAssertEqual(chapter.readingProgress ?? 0, 0.42, accuracy: 0.001)

        diskStore.saveReadingProgress(nil, for: chapter)
        XCTAssertNil(chapter.readingProgress)
    }

    func testNewCollectionDefaultsForUpdateCenterFields() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let c = try store.collections()[0]
        XCTAssertEqual(c.readingStatus, .reading)
        XCTAssertNil(c.lastCheckedAt)
        XCTAssertNil(c.lastNewChapterAt)
        XCTAssertNil(c.lastReadAt)
        XCTAssertEqual(c.unreadCount, 0)
        XCTAssertFalse(c.chapters[0].isNew)
    }

    func testRefreshMergeMarksOnlyAddedChaptersNew() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let c = try store.collections()[0]
        let chapters = store.orderedChapters(of: c)
        XCTAssertFalse(chapters[0].isNew)
        XCTAssertTrue(chapters[1].isNew)
        XCTAssertEqual(c.unreadCount, 1)
        XCTAssertNotNil(c.lastNewChapterAt)
    }

    func testReimportWithNoNewChaptersLeavesTimestampNil() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let c = try store.collections()[0]
        XCTAssertEqual(c.unreadCount, 0)
        XCTAssertNil(c.lastNewChapterAt)
    }

    func testDocImportMergeMarksAddedChapterNew() throws {
        let first = ImportedCollection(
            sourceURLString: "https://vocus.cc/salon/abc/room/def",
            title: "Room", creatorName: "someone", sourceKind: .vocus,
            chapters: [ImportedChapter(title: "A1", urlString: "https://vocus.cc/article/1", orderIndex: 0)])
        try store.applyDocImport(first)
        let second = ImportedCollection(
            sourceURLString: "https://vocus.cc/salon/abc/room/def",
            title: "Room", creatorName: "someone", sourceKind: .vocus,
            chapters: [
                ImportedChapter(title: "A1", urlString: "https://vocus.cc/article/1", orderIndex: 0),
                ImportedChapter(title: "A2", urlString: "https://vocus.cc/article/2", orderIndex: 1)
            ])
        try store.applyDocImport(second)
        let c = try store.collections()[0]
        XCTAssertEqual(c.unreadCount, 1)
        XCTAssertNotNil(c.lastNewChapterAt)
        XCTAssertTrue(c.chapters.first { $0.urlString.hasSuffix("/2") }!.isNew)
    }

    func testMarkChapterOpenedClearsIsNewAndSetsLastReadAt() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let c = try store.collections()[0]
        let newChapter = store.orderedChapters(of: c)[1]
        XCTAssertTrue(newChapter.isNew)
        store.markChapterOpened(newChapter)
        XCTAssertFalse(newChapter.isNew)
        XCTAssertNotNil(c.lastReadAt)
        XCTAssertEqual(c.unreadCount, 0)
    }

    func testMarkAllReadClearsEveryNewFlag() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1),
            payload("6 傷", "https://patreon.com/posts/6-4", order: 2)
        ])
        let c = try store.collections()[0]
        XCTAssertEqual(c.unreadCount, 2)

        store.markAllRead(c)

        XCTAssertEqual(c.unreadCount, 0)
        XCTAssertTrue(c.chapters.allSatisfy { !$0.isNew })
        XCTAssertNotNil(c.lastReadAt)
    }

    func testMarkAllReadOnAlreadyReadCollectionIsNoOp() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let c = try store.collections()[0]
        XCTAssertEqual(c.unreadCount, 0)
        store.markAllRead(c)
        XCTAssertEqual(c.unreadCount, 0)
        XCTAssertNotNil(c.lastReadAt)
    }

    func testSetReadingStatusPersists() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let c = try store.collections()[0]
        store.setReadingStatus(.finished, for: c)
        XCTAssertEqual(try store.collections()[0].readingStatus, .finished)
    }

    func testRecordCheckSetsLastCheckedAtOnly() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let c = try store.collections()[0]
        store.recordCheck(c)
        XCTAssertNotNil(c.lastCheckedAt)
        XCTAssertNil(c.lastNewChapterAt)
        XCTAssertNil(c.lastReadAt)
    }

    func testApplyDocImportPreservesContentHTMLWhenIncomingIsNil() throws {
        let initial = ImportedCollection(
            sourceURLString: "https://archiveofourown.org/works/12345",
            title: "Test Work", creatorName: "Author",
            sourceKind: .ao3,
            chapters: [ImportedChapter(title: "Ch 1",
                                        urlString: "https://archiveofourown.org/works/12345/chapters/111",
                                        orderIndex: 0, contentHTML: "<p>Saved content</p>")])
        try store.applyDocImport(initial)

        let reimport = ImportedCollection(
            sourceURLString: "https://archiveofourown.org/works/12345",
            title: "Test Work", creatorName: "Author",
            sourceKind: .ao3,
            chapters: [ImportedChapter(title: "Ch 1 (updated title)",
                                        urlString: "https://archiveofourown.org/works/12345/chapters/111",
                                        orderIndex: 0, contentHTML: nil)])
        try store.applyDocImport(reimport)

        let collections = try store.collections()
        let chapter = collections.first!.chapters.first!
        XCTAssertEqual(chapter.title, "Ch 1 (updated title)")
        XCTAssertEqual(chapter.contentHTML, "<p>Saved content</p>",
                       "nil contentHTML must not overwrite stored content")
    }
}
