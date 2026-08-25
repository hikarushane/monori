import Foundation
import XCTest
import SwiftData
@testable import MonoriCore

@MainActor
final class LibraryBackupTests: XCTestCase {
    private var store: LibraryStore!

    override func setUp() async throws {
        store = try LibraryStore.inMemory()
    }

    private func seedLibrary() throws {
        let c1 = ImportedCollection(
            sourceURLString: "https://patreon.com/collection/1",
            title: "Story A", creatorName: "Author", sourceKind: .patreon,
            chapters: [
                ImportedChapter(title: "Ch1", urlString: "https://patreon.com/posts/1", orderIndex: 0),
                ImportedChapter(title: "Ch2", urlString: "https://patreon.com/posts/2", orderIndex: 1)
            ])
        try store.applyDocImport(c1)
        let c2 = ImportedCollection(
            sourceURLString: "https://vocus.cc/salon/a/room/b",
            title: "Story B", creatorName: "Writer", sourceKind: .vocus,
            chapters: [
                ImportedChapter(title: "Art1", urlString: "https://vocus.cc/article/x", orderIndex: 0)
            ])
        try store.applyDocImport(c2)

        let collections = try store.collections()
        let storyA = collections.first { $0.title == "Story A" }!
        let ch1 = storyA.chapters.first { $0.title == "Ch1" }!
        let ch2 = storyA.chapters.first { $0.title == "Ch2" }!

        store.toggleBookmark(ch2)
        store.saveReadingProgress(0.42, for: ch1)
        store.setReadingStatus(.reading, for: storyA)
        store.recordChapterOpened(ch1)
        store.recordChapterOpened(ch2)

        let storyB = collections.first { $0.title == "Story B" }!
        let art1 = storyB.chapters.first!
        store.recordChapterOpened(art1)
    }

    // MARK: - Round-trip

    func testBackupRoundTripPreservesAllData() throws {
        try seedLibrary()
        let snapshot = try store.makeBackupSnapshot()

        let target = try LibraryStore.inMemory()
        try target.restoreBackupSnapshot(snapshot)

        let collections = try target.collections()
        XCTAssertEqual(collections.count, 2)

        let storyA = collections.first { $0.title == "Story A" }!
        XCTAssertEqual(storyA.sourceURLString, "https://patreon.com/collection/1")
        XCTAssertEqual(storyA.creatorName, "Author")
        XCTAssertEqual(storyA.sourceKindRaw, SourceKind.patreon.rawValue)
        XCTAssertEqual(storyA.readingStatus, .reading)
        XCTAssertNotNil(storyA.lastReadAt)
        XCTAssertEqual(storyA.chapters.count, 2)

        let ch1 = storyA.chapters.first { $0.title == "Ch1" }!
        XCTAssertEqual(ch1.readingProgress, 0.42)
        XCTAssertFalse(ch1.isBookmarked)

        let ch2 = storyA.chapters.first { $0.title == "Ch2" }!
        XCTAssertTrue(ch2.isBookmarked)

        let storyB = collections.first { $0.title == "Story B" }!
        XCTAssertEqual(storyB.sourceKind, .vocus)
        XCTAssertEqual(storyB.chapters.count, 1)

        let history = try target.readingHistory()
        XCTAssertEqual(history.count, 3)
    }

    // MARK: - HTML exclusion

    func testBackupExcludesContentHTML() throws {
        let imported = ImportedCollection(
            sourceURLString: "https://ao3.org/works/1",
            title: "AO3 Work", creatorName: nil, sourceKind: .ao3,
            chapters: [ImportedChapter(title: "Ch1", urlString: "https://ao3.org/works/1/chapters/1",
                                        orderIndex: 0, contentHTML: "<p>private paid content</p>")])
        try store.applyDocImport(imported)

        let snapshot = try store.makeBackupSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertFalse(json.contains("private paid content"), "contentHTML must not appear in backup")
        XCTAssertFalse(json.contains("contentHTML"), "contentHTML key must not appear in backup")
    }

    // MARK: - Bookmark invariant

    func testBackupRejectsMultipleBookmarksInOneCollection() throws {
        try seedLibrary()
        var snapshot = try store.makeBackupSnapshot()

        var modifiedCollection = snapshot.collections[0]
        let allBookmarked = modifiedCollection.chapters.map { ch in
            ChapterBackup(id: ch.id, title: ch.title, urlString: ch.urlString,
                          orderIndex: ch.orderIndex, visibleDateText: ch.visibleDateText,
                          excerpt: ch.excerpt, isBookmarked: true,
                          isNew: ch.isNew, readingProgress: ch.readingProgress)
        }
        modifiedCollection = CollectionBackup(
            id: modifiedCollection.id, title: modifiedCollection.title,
            sourceURLString: modifiedCollection.sourceURLString,
            creatorName: modifiedCollection.creatorName,
            sortDirectionRaw: modifiedCollection.sortDirectionRaw,
            sourceKindRaw: modifiedCollection.sourceKindRaw,
            readingStatusRaw: modifiedCollection.readingStatusRaw,
            lastCheckedAt: modifiedCollection.lastCheckedAt,
            lastNewChapterAt: modifiedCollection.lastNewChapterAt,
            lastReadAt: modifiedCollection.lastReadAt,
            chapters: allBookmarked)

        var collections = snapshot.collections
        collections[0] = modifiedCollection
        snapshot = LibraryBackupEnvelope(
            schemaVersion: snapshot.schemaVersion, createdAt: snapshot.createdAt,
            appVersion: snapshot.appVersion, collections: collections,
            readingHistory: snapshot.readingHistory)

        let target = try LibraryStore.inMemory()
        XCTAssertThrowsError(try target.restoreBackupSnapshot(snapshot)) { error in
            guard let e = error as? BackupValidationError,
                  case .multipleBookmarksInCollection = e else {
                XCTFail("Expected multipleBookmarksInCollection, got \(error)")
                return
            }
        }
    }

    // MARK: - ID preservation

    func testRestorePreservesIDs() throws {
        try seedLibrary()
        let snapshot = try store.makeBackupSnapshot()
        let originalCollectionIDs = Set(snapshot.collections.map(\.id))
        let originalChapterIDs = Set(snapshot.collections.flatMap { $0.chapters.map(\.id) })
        let originalHistoryIDs = Set(snapshot.readingHistory.map(\.id))

        let target = try LibraryStore.inMemory()
        try target.restoreBackupSnapshot(snapshot)

        let restoredCollectionIDs = Set(try target.collections().map(\.id))
        let restoredChapterIDs = Set(try target.collections().flatMap { $0.chapters.map(\.id) })
        let restoredHistoryIDs = Set(try target.readingHistory().map(\.id))

        XCTAssertEqual(originalCollectionIDs, restoredCollectionIDs)
        XCTAssertEqual(originalChapterIDs, restoredChapterIDs)
        XCTAssertEqual(originalHistoryIDs, restoredHistoryIDs)
    }

    // MARK: - Repeated restore

    func testRepeatedRestoreDoesNotDuplicate() throws {
        try seedLibrary()
        let snapshot = try store.makeBackupSnapshot()

        let target = try LibraryStore.inMemory()
        try target.restoreBackupSnapshot(snapshot)
        try target.restoreBackupSnapshot(snapshot)

        XCTAssertEqual(try target.collectionCount(), 2)
        XCTAssertEqual(try target.readingHistoryCount(), 3)
    }

    // MARK: - Unsupported schema version

    func testUnsupportedSchemaVersionRejects() throws {
        let future = LibraryBackupEnvelope(
            schemaVersion: 999, createdAt: .now, appVersion: nil,
            collections: [], readingHistory: [])

        XCTAssertThrowsError(try store.restoreBackupSnapshot(future)) { error in
            guard let e = error as? BackupValidationError,
                  case .unsupportedSchemaVersion(999) = e else {
                XCTFail("Expected unsupportedSchemaVersion, got \(error)")
                return
            }
        }
        XCTAssertEqual(try store.collectionCount(), 0)
    }

    // MARK: - Corrupted payload

    func testCorruptedPayloadLeavesStoreUntouched() throws {
        try seedLibrary()
        let originalCount = try store.collectionCount()

        let badJSON = Data("{ invalid json".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(LibraryBackupEnvelope.self, from: badJSON))

        XCTAssertEqual(try store.collectionCount(), originalCount,
                       "Store must be untouched after decode failure")
    }

    // MARK: - Validation edge cases

    func testDuplicateCollectionIDRejects() throws {
        let bad = LibraryBackupEnvelope(
            schemaVersion: 1, createdAt: .now, appVersion: nil,
            collections: [
                CollectionBackup(id: "dup", title: "A", sourceURLString: "https://a.com",
                                 creatorName: nil, sortDirectionRaw: "oldestToNewest",
                                 sourceKindRaw: "patreon", readingStatusRaw: "reading",
                                 lastCheckedAt: nil, lastNewChapterAt: nil, lastReadAt: nil,
                                 chapters: []),
                CollectionBackup(id: "dup", title: "B", sourceURLString: "https://b.com",
                                 creatorName: nil, sortDirectionRaw: "oldestToNewest",
                                 sourceKindRaw: "patreon", readingStatusRaw: "reading",
                                 lastCheckedAt: nil, lastNewChapterAt: nil, lastReadAt: nil,
                                 chapters: [])
            ], readingHistory: [])

        XCTAssertThrowsError(try store.restoreBackupSnapshot(bad))
    }

    func testInvalidReadingProgressRejects() throws {
        let bad = LibraryBackupEnvelope(
            schemaVersion: 1, createdAt: .now, appVersion: nil,
            collections: [
                CollectionBackup(id: "c1", title: "C", sourceURLString: "https://c.com",
                                 creatorName: nil, sortDirectionRaw: "oldestToNewest",
                                 sourceKindRaw: "patreon", readingStatusRaw: "reading",
                                 lastCheckedAt: nil, lastNewChapterAt: nil, lastReadAt: nil,
                                 chapters: [
                                    ChapterBackup(id: "ch1", title: "X", urlString: "https://c.com/1",
                                                  orderIndex: 0, visibleDateText: nil, excerpt: nil,
                                                  isBookmarked: false, isNew: false, readingProgress: 1.5)
                                 ])
            ], readingHistory: [])

        XCTAssertThrowsError(try store.restoreBackupSnapshot(bad)) { error in
            guard let e = error as? BackupValidationError,
                  case .invalidReadingProgress = e else {
                XCTFail("Expected invalidReadingProgress, got \(error)")
                return
            }
        }
    }

    func testEmptyChapterURLRejects() throws {
        let bad = LibraryBackupEnvelope(
            schemaVersion: 1, createdAt: .now, appVersion: nil,
            collections: [
                CollectionBackup(id: "c1", title: "C", sourceURLString: "https://c.com",
                                 creatorName: nil, sortDirectionRaw: "oldestToNewest",
                                 sourceKindRaw: "patreon", readingStatusRaw: "reading",
                                 lastCheckedAt: nil, lastNewChapterAt: nil, lastReadAt: nil,
                                 chapters: [
                                    ChapterBackup(id: "ch1", title: "X", urlString: "",
                                                  orderIndex: 0, visibleDateText: nil, excerpt: nil,
                                                  isBookmarked: false, isNew: false, readingProgress: nil)
                                 ])
            ], readingHistory: [])

        XCTAssertThrowsError(try store.restoreBackupSnapshot(bad))
    }

    // MARK: - Restore failure rollback

    func testRestoreFailurePreservesExistingData() throws {
        try seedLibrary()
        let originalCollections = try store.collectionCount()
        let originalHistory = try store.readingHistoryCount()

        let bad = LibraryBackupEnvelope(
            schemaVersion: 999, createdAt: .now, appVersion: nil,
            collections: [], readingHistory: [])

        XCTAssertThrowsError(try store.restoreBackupSnapshot(bad))
        XCTAssertEqual(try store.collectionCount(), originalCollections)
        XCTAssertEqual(try store.readingHistoryCount(), originalHistory)
    }

    // MARK: - Encode / decode round-trip

    func testJSONEncodeDecode() throws {
        try seedLibrary()
        let snapshot = try store.makeBackupSnapshot()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LibraryBackupEnvelope.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, snapshot.schemaVersion)
        XCTAssertEqual(decoded.collectionCount, snapshot.collectionCount)
        XCTAssertEqual(decoded.chapterCount, snapshot.chapterCount)
        XCTAssertEqual(decoded.historyCount, snapshot.historyCount)
        try decoded.validate()
    }
}
