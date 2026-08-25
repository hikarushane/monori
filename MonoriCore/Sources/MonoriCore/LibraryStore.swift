import Foundation
import SwiftData

@MainActor
public final class LibraryStore {
    public let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public static let historyCoalescingInterval: TimeInterval = 300

    public init(container: ModelContainer) {
        self.container = container
    }

    public static func inMemory() throws -> LibraryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LocalCollectionModel.self, LocalChapterModel.self,
            LocalReadingHistoryEntry.self,
            configurations: config)
        return LibraryStore(container: container)
    }

    public static func onDisk() throws -> LibraryStore {
        let config = ModelConfiguration(cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: LocalCollectionModel.self, LocalChapterModel.self,
            LocalReadingHistoryEntry.self,
            configurations: config)
        return LibraryStore(container: container)
    }

    // MARK: import

    public func applyImport(_ payloads: [ImporterChapterPayload]) throws {
        guard let first = payloads.first,
              let collectionURL = URLNormalizer.normalize(first.collectionURL)?.absoluteString
        else { return }

        let collection = try findCollection(sourceURLString: collectionURL)
            ?? {
                let c = LocalCollectionModel(title: first.collectionName,
                                             sourceURLString: collectionURL,
                                             creatorName: first.creatorName)
                context.insert(c)
                return c
            }()
        if collection.creatorName?.isEmpty ?? true {
            collection.creatorName = first.creatorName
        }
        // Re-import syncs the title from the page so a name scraped wrong
        // once (e.g. owner-view "Customize this collection") heals itself.
        if !first.collectionName.isEmpty {
            collection.title = first.collectionName
        }

        // A merge into a collection that already has chapters is a refresh;
        // chapters inserted below are "new" in the update-center sense.
        // The initial import of a (possibly complete) serial is not.
        let isRefreshMerge = !collection.chapters.isEmpty
        var insertedNewChapter = false

        let existing = collection.chapters
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { ChapterRecord(title: $0.title, urlString: $0.urlString,
                                 visibleDateText: $0.visibleDateText,
                                 excerpt: $0.excerpt, orderIndex: $0.orderIndex) }
        let merged = ChapterMapMerger.merge(existing: existing, incoming: payloads)

        var existingByURL: [String: LocalChapterModel] = [:]
        for chapter in collection.chapters where existingByURL[chapter.urlString] == nil {
            existingByURL[chapter.urlString] = chapter
        }
        for record in merged {
            if let chapter = existingByURL[record.urlString] {
                chapter.title = record.title
                if chapter.visibleDateText == nil {
                    chapter.visibleDateText = record.visibleDateText
                }
                if chapter.excerpt == nil {
                    chapter.excerpt = record.excerpt
                }
            } else {
                let chapter = LocalChapterModel(title: record.title, urlString: record.urlString,
                                                orderIndex: record.orderIndex,
                                                visibleDateText: record.visibleDateText,
                                                excerpt: record.excerpt)
                chapter.isNew = isRefreshMerge
                insertedNewChapter = true
                chapter.collection = collection
                context.insert(chapter)
            }
        }
        if isRefreshMerge && insertedNewChapter {
            collection.lastNewChapterAt = Date()
        }
        try context.save()
    }

    public func applyDocImport(_ imported: ImportedCollection) throws {
        let collection: LocalCollectionModel
        if let existing = try findCollection(sourceURLString: imported.sourceURLString) {
            collection = existing
        } else {
            let c = LocalCollectionModel(title: imported.title,
                                         sourceURLString: imported.sourceURLString,
                                         creatorName: imported.creatorName,
                                         sourceKind: imported.sourceKind)
            context.insert(c)
            collection = c
        }

        // A merge into a collection that already has chapters is a refresh;
        // chapters inserted below are "new" in the update-center sense.
        // The initial import of a (possibly complete) serial is not.
        let isRefreshMerge = !collection.chapters.isEmpty
        var insertedNewChapter = false

        var existingByURL: [String: LocalChapterModel] = [:]
        for chapter in collection.chapters where existingByURL[chapter.urlString] == nil {
            existingByURL[chapter.urlString] = chapter
        }
        for ic in imported.chapters {
            if let chapter = existingByURL[ic.urlString] {
                chapter.title = ic.title
                chapter.orderIndex = ic.orderIndex
                if let html = ic.contentHTML {
                    chapter.contentHTML = html
                }
            } else {
                let chapter = LocalChapterModel(title: ic.title, urlString: ic.urlString,
                                                orderIndex: ic.orderIndex)
                chapter.isNew = isRefreshMerge
                insertedNewChapter = true
                chapter.contentHTML = ic.contentHTML
                chapter.collection = collection
                context.insert(chapter)
            }
        }
        if isRefreshMerge && insertedNewChapter {
            collection.lastNewChapterAt = Date()
        }
        try context.save()
    }

    // MARK: queries

    public func collections() throws -> [LocalCollectionModel] {
        try context.fetch(FetchDescriptor<LocalCollectionModel>(
            sortBy: [SortDescriptor(\.title)]))
    }

    public func collectionCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<LocalCollectionModel>())
    }

    public func orderedChapters(of collection: LocalCollectionModel) -> [LocalChapterModel] {
        let oldestToNewest = collection.chapters.sorted {
            ChapterOrdering.sortKey(urlString: $0.urlString, orderIndex: $0.orderIndex)
                < ChapterOrdering.sortKey(urlString: $1.urlString, orderIndex: $1.orderIndex)
        }
        return collection.sortDirection == .oldestToNewest ? oldestToNewest : oldestToNewest.reversed()
    }

    public func neighbors(of chapter: LocalChapterModel)
        -> (previous: LocalChapterModel?, next: LocalChapterModel?) {
        guard let collection = chapter.collection else { return (nil, nil) }
        // One source of truth with orderedChapters: oldest → newest by post ID.
        // previous == the older chapter, next == the newer chapter.
        let storyOrder = collection.chapters.sorted {
            ChapterOrdering.sortKey(urlString: $0.urlString, orderIndex: $0.orderIndex)
                < ChapterOrdering.sortKey(urlString: $1.urlString, orderIndex: $1.orderIndex)
        }
        guard let i = storyOrder.firstIndex(where: { $0.id == chapter.id }) else { return (nil, nil) }
        return (i > 0 ? storyOrder[i - 1] : nil,
                i < storyOrder.count - 1 ? storyOrder[i + 1] : nil)
    }

    public func chapter(withPageURL pageURL: String) -> LocalChapterModel? {
        // 1. Patreon: normalize URL then match
        if let normalized = URLNormalizer.normalize(pageURL)?.absoluteString {
            var descriptor = FetchDescriptor<LocalChapterModel>(
                predicate: #Predicate { $0.urlString == normalized })
            descriptor.fetchLimit = 1
            if let exact = try? context.fetch(descriptor).first {
                return exact
            }
            if let postID = URLNormalizer.patreonPostID(pageURL),
               let chapters = try? context.fetch(FetchDescriptor<LocalChapterModel>())
            {
                return chapters.first { URLNormalizer.patreonPostID($0.urlString) == postID }
            }
        }

        // 2. Vocus: canonicalize article URL then match
        if let canonical = URLNormalizer.canonicalVocusArticleURL(pageURL) {
            var descriptor = FetchDescriptor<LocalChapterModel>(
                predicate: #Predicate { $0.urlString == canonical })
            descriptor.fetchLimit = 1
            return try? context.fetch(descriptor).first
        }

        // 3. AFF: canonicalize chapter URL then match
        if let canonical = URLNormalizer.canonicalAFFChapterURL(pageURL) {
            var descriptor = FetchDescriptor<LocalChapterModel>(
                predicate: #Predicate { $0.urlString == canonical })
            descriptor.fetchLimit = 1
            if let exact = try? context.fetch(descriptor).first {
                return exact
            }
            // Stored URL may include slug suffix; normalize both sides
            if let chapters = try? context.fetch(FetchDescriptor<LocalChapterModel>()) {
                return chapters.first {
                    URLNormalizer.canonicalAFFChapterURL($0.urlString) == canonical
                }
            }
        }

        // 4. AO3: canonicalize chapter URL then match
        if let canonical = URLNormalizer.canonicalAO3ChapterURL(pageURL) {
            var descriptor = FetchDescriptor<LocalChapterModel>(
                predicate: #Predicate { $0.urlString == canonical })
            descriptor.fetchLimit = 1
            if let exact = try? context.fetch(descriptor).first {
                return exact
            }
            // Stored URL may not be canonical (older imports); normalize both sides
            if let chapters = try? context.fetch(FetchDescriptor<LocalChapterModel>()) {
                return chapters.first {
                    URLNormalizer.canonicalAO3ChapterURL($0.urlString) == canonical
                }
            }
        }

        return nil
    }

    // MARK: edits

    public func toggleBookmark(_ chapter: LocalChapterModel) {
        if chapter.isBookmarked {
            chapter.isBookmarked = false
        } else {
            if let collection = chapter.collection {
                for sibling in collection.chapters where sibling.id != chapter.id && sibling.isBookmarked {
                    sibling.isBookmarked = false
                }
            }
            chapter.isBookmarked = true
        }
        try? context.save()
    }

    public func saveReadingProgress(_ progress: Double?, for chapter: LocalChapterModel) {
        chapter.readingProgress = progress
        try? context.save()
    }

    public func rename(_ chapter: LocalChapterModel, to title: String) {
        chapter.title = String(title.prefix(PayloadValidator.maxFieldLength))
        try? context.save()
    }

    public func delete(_ chapter: LocalChapterModel) {
        context.delete(chapter)
        try? context.save()
    }

    public func deleteCollection(_ collection: LocalCollectionModel) {
        context.delete(collection)   // cascade deletes chapters
        try? context.save()
    }

    public func clearLibrary() throws {
        for collection in try collections() { context.delete(collection) }
        for entry in try readingHistory() { context.delete(entry) }
        try context.save()
    }

    public func readingHistory() throws -> [LocalReadingHistoryEntry] {
        try context.fetch(FetchDescriptor<LocalReadingHistoryEntry>(
            sortBy: [SortDescriptor(\.openedAt, order: .reverse)]))
    }

    public func readingHistoryCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<LocalReadingHistoryEntry>())
    }

    public func recordChapterOpened(_ chapter: LocalChapterModel, at date: Date = .now) {
        chapter.isNew = false
        chapter.collection?.lastReadAt = date
        coalesceOrInsertHistory(for: chapter, at: date)
        try? context.save()
    }

    @available(*, deprecated, renamed: "recordChapterOpened(_:at:)")
    public func markChapterOpened(_ chapter: LocalChapterModel, at date: Date = .now) {
        recordChapterOpened(chapter, at: date)
    }

    private func coalesceOrInsertHistory(for chapter: LocalChapterModel, at date: Date) {
        let chapterID = chapter.id
        let threshold = date.addingTimeInterval(-Self.historyCoalescingInterval)
        var descriptor = FetchDescriptor<LocalReadingHistoryEntry>(
            predicate: #Predicate { $0.chapterID == chapterID && $0.openedAt > threshold },
            sortBy: [SortDescriptor(\.openedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.openedAt = date
            return
        }
        let collectionID = chapter.collection?.id ?? ""
        let collectionTitle = chapter.collection?.title ?? ""
        let sourceKindRaw = chapter.collection?.sourceKindRaw ?? SourceKind.patreon.rawValue
        let entry = LocalReadingHistoryEntry(
            collectionID: collectionID,
            chapterID: chapterID,
            collectionTitle: collectionTitle,
            chapterTitle: chapter.title,
            chapterURLString: chapter.urlString,
            sourceKindRaw: sourceKindRaw,
            openedAt: date)
        context.insert(entry)
    }

    /// Clears the unread dot on every chapter in the collection at once.
    public func markAllRead(_ collection: LocalCollectionModel, at date: Date = .now) {
        for chapter in collection.chapters where chapter.isNew {
            chapter.isNew = false
        }
        collection.lastReadAt = date
        try? context.save()
    }

    public func setReadingStatus(_ status: CollectionReadingStatus,
                                 for collection: LocalCollectionModel) {
        collection.readingStatus = status
        try? context.save()
    }

    /// Stamps a completed (auto or manual) new-chapter check, successful or not,
    /// so the cooldown holds regardless of outcome.
    public func recordCheck(_ collection: LocalCollectionModel, at date: Date = .now) {
        collection.lastCheckedAt = date
        try? context.save()
    }

    // MARK: private

    private func findCollection(sourceURLString: String) throws -> LocalCollectionModel? {
        var descriptor = FetchDescriptor<LocalCollectionModel>(
            predicate: #Predicate { $0.sourceURLString == sourceURLString })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
