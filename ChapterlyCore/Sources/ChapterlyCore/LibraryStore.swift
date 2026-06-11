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
                                 visibleDateText: $0.visibleDateText, orderIndex: $0.orderIndex) }
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
            } else {
                let chapter = LocalChapterModel(title: record.title, urlString: record.urlString,
                                                orderIndex: record.orderIndex,
                                                visibleDateText: record.visibleDateText)
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
        let asc = collection.chapters.sorted { $0.orderIndex < $1.orderIndex }
        return collection.sortDirection == .oldestToNewest ? asc : asc.reversed()
    }

    public func neighbors(of chapter: LocalChapterModel)
        -> (previous: LocalChapterModel?, next: LocalChapterModel?) {
        guard let collection = chapter.collection else { return (nil, nil) }
        let ordered = orderedChapters(of: collection)
        guard let i = ordered.firstIndex(where: { $0.id == chapter.id }) else { return (nil, nil) }
        return (i > 0 ? ordered[i - 1] : nil,
                i < ordered.count - 1 ? ordered[i + 1] : nil)
    }

    public func chapter(withPageURL pageURL: String) -> LocalChapterModel? {
        guard let normalized = URLNormalizer.normalize(pageURL)?.absoluteString else { return nil }
        var descriptor = FetchDescriptor<LocalChapterModel>(
            predicate: #Predicate { $0.urlString == normalized })
        descriptor.fetchLimit = 1
        if let exact = try? context.fetch(descriptor).first {
            return exact
        }
        guard let postID = URLNormalizer.patreonPostID(pageURL),
              let chapters = try? context.fetch(FetchDescriptor<LocalChapterModel>())
        else { return nil }
        return chapters.first { URLNormalizer.patreonPostID($0.urlString) == postID }
    }

    // MARK: edits

    public func setProgress(forPageURL pageURL: String, progress: Double) {
        guard ReaderProgressPolicy.shouldStore(progress) else { return }
        guard let chapter = chapter(withPageURL: pageURL) else { return }
        chapter.readingProgress = min(1.0, max(0.0, progress))
        chapter.lastReadAt = Date()
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

    public func addManualChapter(to collection: LocalCollectionModel,
                                 title: String, urlString: String) throws {
        guard let normalized = URLNormalizer.normalize(urlString)?.absoluteString else { return }
        guard !collection.chapters.contains(where: { $0.urlString == normalized }) else { return }
        let nextIndex = (collection.chapters.map(\.orderIndex).max() ?? -1) + 1
        let chapter = LocalChapterModel(title: title, urlString: normalized, orderIndex: nextIndex)
        chapter.collection = collection
        context.insert(chapter)
        try context.save()
    }

    public func moveChapters(in collection: LocalCollectionModel, from source: IndexSet, to destination: Int) {
        let ordered = orderedChapters(of: collection)
        // Manually reorder: collect items being moved, remove them, then insert at destination.
        let moving = source.map { ordered[$0] }
        var remaining = ordered.enumerated()
            .filter { !source.contains($0.offset) }
            .map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: min(insertAt, remaining.count))
        let canonical: [LocalChapterModel] = collection.sortDirection == .oldestToNewest
            ? remaining
            : remaining.reversed()
        for (i, chapter) in canonical.enumerated() { chapter.orderIndex = i }
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
