import Foundation
import SwiftData

public struct LibraryBackupEnvelope: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let createdAt: Date
    public let appVersion: String?
    public let collections: [CollectionBackup]
    public let readingHistory: [ReadingHistoryBackup]

    public var collectionCount: Int { collections.count }
    public var chapterCount: Int { collections.reduce(0) { $0 + $1.chapters.count } }
    public var historyCount: Int { readingHistory.count }
}

public struct CollectionBackup: Codable, Sendable {
    public let id: String
    public let title: String
    public let sourceURLString: String
    public let creatorName: String?
    public let sortDirectionRaw: String
    public let sourceKindRaw: String
    public let readingStatusRaw: String
    public let lastCheckedAt: Date?
    public let lastNewChapterAt: Date?
    public let lastReadAt: Date?
    public let chapters: [ChapterBackup]
}

public struct ChapterBackup: Codable, Sendable {
    public let id: String
    public let title: String
    public let urlString: String
    public let orderIndex: Int
    public let visibleDateText: String?
    public let excerpt: String?
    public let isBookmarked: Bool
    public let isNew: Bool
    public let readingProgress: Double?
}

public struct ReadingHistoryBackup: Codable, Sendable {
    public let id: String
    public let collectionID: String
    public let chapterID: String
    public let collectionTitle: String
    public let chapterTitle: String
    public let chapterURLString: String
    public let sourceKindRaw: String
    public let openedAt: Date
}

// MARK: - Validation

public enum BackupValidationError: Error, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case duplicateCollectionID(String)
    case duplicateChapterID(String)
    case chapterURLEmpty(chapterID: String)
    case multipleBookmarksInCollection(collectionID: String)
    case invalidReadingProgress(chapterID: String, value: Double)
    case historyMissingRequiredField(entryID: String)
    case decodingFailed(Error)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let v):
            return "Unsupported backup schema version: \(v)"
        case .duplicateCollectionID(let id):
            return "Duplicate collection ID: \(id)"
        case .duplicateChapterID(let id):
            return "Duplicate chapter ID: \(id)"
        case .chapterURLEmpty(let id):
            return "Empty chapter URL for chapter: \(id)"
        case .multipleBookmarksInCollection(let id):
            return "Multiple bookmarks in collection: \(id)"
        case .invalidReadingProgress(let id, let v):
            return "Invalid reading progress \(v) for chapter: \(id)"
        case .historyMissingRequiredField(let id):
            return "History entry missing required field: \(id)"
        case .decodingFailed(let e):
            return "Backup decoding failed: \(e.localizedDescription)"
        }
    }
}

extension LibraryBackupEnvelope {
    public func validate() throws {
        guard schemaVersion >= 1, schemaVersion <= Self.currentSchemaVersion else {
            throw BackupValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        var seenCollectionIDs = Set<String>()
        var seenChapterIDs = Set<String>()
        for collection in collections {
            guard seenCollectionIDs.insert(collection.id).inserted else {
                throw BackupValidationError.duplicateCollectionID(collection.id)
            }
            var bookmarkCount = 0
            for chapter in collection.chapters {
                guard seenChapterIDs.insert(chapter.id).inserted else {
                    throw BackupValidationError.duplicateChapterID(chapter.id)
                }
                guard !chapter.urlString.isEmpty else {
                    throw BackupValidationError.chapterURLEmpty(chapterID: chapter.id)
                }
                if chapter.isBookmarked { bookmarkCount += 1 }
                if let p = chapter.readingProgress, (p < 0 || p > 1) {
                    throw BackupValidationError.invalidReadingProgress(
                        chapterID: chapter.id, value: p)
                }
            }
            if bookmarkCount > 1 {
                throw BackupValidationError.multipleBookmarksInCollection(
                    collectionID: collection.id)
            }
        }
        for entry in readingHistory {
            guard !entry.chapterID.isEmpty, !entry.collectionID.isEmpty else {
                throw BackupValidationError.historyMissingRequiredField(entryID: entry.id)
            }
        }
    }
}

// MARK: - LibraryStore snapshot / restore

extension LibraryStore {
    public func makeBackupSnapshot(now: Date = .now) throws -> LibraryBackupEnvelope {
        let allCollections = try collections()
        let collectionBackups = allCollections.map { c in
            CollectionBackup(
                id: c.id, title: c.title, sourceURLString: c.sourceURLString,
                creatorName: c.creatorName, sortDirectionRaw: c.sortDirectionRaw,
                sourceKindRaw: c.sourceKindRaw, readingStatusRaw: c.readingStatusRaw,
                lastCheckedAt: c.lastCheckedAt, lastNewChapterAt: c.lastNewChapterAt,
                lastReadAt: c.lastReadAt,
                chapters: c.chapters.map { ch in
                    ChapterBackup(
                        id: ch.id, title: ch.title, urlString: ch.urlString,
                        orderIndex: ch.orderIndex, visibleDateText: ch.visibleDateText,
                        excerpt: ch.excerpt, isBookmarked: ch.isBookmarked,
                        isNew: ch.isNew, readingProgress: ch.readingProgress)
                })
        }
        let history = try readingHistory()
        let historyBackups = history.map { h in
            ReadingHistoryBackup(
                id: h.id, collectionID: h.collectionID, chapterID: h.chapterID,
                collectionTitle: h.collectionTitle, chapterTitle: h.chapterTitle,
                chapterURLString: h.chapterURLString, sourceKindRaw: h.sourceKindRaw,
                openedAt: h.openedAt)
        }
        return LibraryBackupEnvelope(
            schemaVersion: LibraryBackupEnvelope.currentSchemaVersion,
            createdAt: now, appVersion: MonoriCore.version,
            collections: collectionBackups, readingHistory: historyBackups)
    }

    public func restoreBackupSnapshot(_ snapshot: LibraryBackupEnvelope) throws {
        try snapshot.validate()
        let rollback = try makeBackupSnapshot()
        do {
            try performRestore(snapshot)
        } catch {
            try? performRestore(rollback)
            throw error
        }
    }

    private func performRestore(_ snapshot: LibraryBackupEnvelope) throws {
        let context = container.mainContext
        for c in try collections() { context.delete(c) }
        for h in try readingHistory() { context.delete(h) }
        try context.save()

        for cb in snapshot.collections {
            let collection = LocalCollectionModel(
                id: cb.id, title: cb.title, sourceURLString: cb.sourceURLString,
                creatorName: cb.creatorName)
            collection.sortDirectionRaw = cb.sortDirectionRaw
            collection.sourceKindRaw = cb.sourceKindRaw
            collection.readingStatusRaw = cb.readingStatusRaw
            collection.lastCheckedAt = cb.lastCheckedAt
            collection.lastNewChapterAt = cb.lastNewChapterAt
            collection.lastReadAt = cb.lastReadAt
            context.insert(collection)
            for chb in cb.chapters {
                let chapter = LocalChapterModel(
                    id: chb.id, title: chb.title, urlString: chb.urlString,
                    orderIndex: chb.orderIndex, visibleDateText: chb.visibleDateText,
                    excerpt: chb.excerpt)
                chapter.isBookmarked = chb.isBookmarked
                chapter.isNew = chb.isNew
                chapter.readingProgress = chb.readingProgress
                chapter.collection = collection
                context.insert(chapter)
            }
        }
        for hb in snapshot.readingHistory {
            let entry = LocalReadingHistoryEntry(
                id: hb.id, collectionID: hb.collectionID, chapterID: hb.chapterID,
                collectionTitle: hb.collectionTitle, chapterTitle: hb.chapterTitle,
                chapterURLString: hb.chapterURLString, sourceKindRaw: hb.sourceKindRaw,
                openedAt: hb.openedAt)
            context.insert(entry)
        }
        try context.save()
    }
}
