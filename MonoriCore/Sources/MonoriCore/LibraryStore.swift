import Foundation
import SwiftData

@MainActor
public final class LibraryStore {
    public let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    public static func inMemory() throws -> LibraryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalCollectionModel.self, LocalChapterModel.self,
                                           configurations: config)
        return LibraryStore(container: container)
    }

    public static func onDisk() throws -> LibraryStore {
        let container = try ModelContainer(for: LocalCollectionModel.self, LocalChapterModel.self)
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
                chapter.collection = collection
                context.insert(chapter)
            }
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

        var existingByURL: [String: LocalChapterModel] = [:]
        for chapter in collection.chapters where existingByURL[chapter.urlString] == nil {
            existingByURL[chapter.urlString] = chapter
        }
        for ic in imported.chapters {
            if let chapter = existingByURL[ic.urlString] {
                chapter.title = ic.title
                chapter.orderIndex = ic.orderIndex
                chapter.contentHTML = ic.contentHTML
            } else {
                let chapter = LocalChapterModel(title: ic.title, urlString: ic.urlString,
                                                orderIndex: ic.orderIndex)
                chapter.contentHTML = ic.contentHTML
                chapter.collection = collection
                context.insert(chapter)
            }
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

        return nil
    }

    // MARK: edits

    public func toggleBookmark(_ chapter: LocalChapterModel) {
        chapter.isBookmarked.toggle()
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
        try context.save()
    }

    // MARK: private

    private func findCollection(sourceURLString: String) throws -> LocalCollectionModel? {
        var descriptor = FetchDescriptor<LocalCollectionModel>(
            predicate: #Predicate { $0.sourceURLString == sourceURLString })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
