import Foundation
import SwiftData

public enum CollectionSortDirection: String, Codable {
    case oldestToNewest
    case newestToOldest
}

public enum CollectionReadingStatus: String, Codable, CaseIterable, Sendable {
    case reading
    case finished
    case dropped
}

@Model
public final class LocalCollectionModel {
    @Attribute(.unique) public var id: String
    public var title: String
    public var sourceURLString: String        // normalized
    public var creatorName: String?
    public var sortDirectionRaw: String
    public var sourceKindRaw: String = SourceKind.patreon.rawValue
    public var readingStatusRaw: String = CollectionReadingStatus.reading.rawValue
    public var lastCheckedAt: Date?
    public var lastNewChapterAt: Date?
    public var lastReadAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \LocalChapterModel.collection)
    public var chapters: [LocalChapterModel]

    public var sortDirection: CollectionSortDirection {
        get { CollectionSortDirection(rawValue: sortDirectionRaw) ?? .oldestToNewest }
        set { sortDirectionRaw = newValue.rawValue }
    }

    public var sourceKind: SourceKind {
        get { SourceKind(rawValue: sourceKindRaw) ?? .patreon }
        set { sourceKindRaw = newValue.rawValue }
    }

    public var readingStatus: CollectionReadingStatus {
        get { CollectionReadingStatus(rawValue: readingStatusRaw) ?? .reading }
        set { readingStatusRaw = newValue.rawValue }
    }

    /// Chapters discovered by a refresh and not yet opened.
    public var unreadCount: Int { chapters.filter(\.isNew).count }

    public init(id: String = UUID().uuidString,
                title: String,
                sourceURLString: String,
                creatorName: String? = nil,
                sortDirection: CollectionSortDirection = .oldestToNewest,
                sourceKind: SourceKind = .patreon) {
        self.id = id
        self.title = title
        self.sourceURLString = sourceURLString
        self.creatorName = creatorName
        self.sortDirectionRaw = sortDirection.rawValue
        self.sourceKindRaw = sourceKind.rawValue
        self.chapters = []
    }
}

@Model
public final class LocalChapterModel {
    @Attribute(.unique) public var id: String
    public var title: String
    public var urlString: String              // normalized
    public var orderIndex: Int                // explicit, never derived at query time
    public var visibleDateText: String?
    public var excerpt: String?
    public var isBookmarked: Bool = false
    public var isNew: Bool = false
    public var contentHTML: String?
    public var readingProgress: Double?
    public var collection: LocalCollectionModel?

    public init(id: String = UUID().uuidString,
                title: String,
                urlString: String,
                orderIndex: Int,
                visibleDateText: String? = nil,
                excerpt: String? = nil) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.orderIndex = orderIndex
        self.visibleDateText = visibleDateText
        self.excerpt = excerpt
    }
}

@Model
public final class LocalReadingHistoryEntry {
    @Attribute(.unique) public var id: String
    public var collectionID: String
    public var chapterID: String
    public var collectionTitle: String
    public var chapterTitle: String
    public var chapterURLString: String
    public var sourceKindRaw: String
    public var openedAt: Date

    public init(id: String = UUID().uuidString,
                collectionID: String,
                chapterID: String,
                collectionTitle: String,
                chapterTitle: String,
                chapterURLString: String,
                sourceKindRaw: String,
                openedAt: Date = .now) {
        self.id = id
        self.collectionID = collectionID
        self.chapterID = chapterID
        self.collectionTitle = collectionTitle
        self.chapterTitle = chapterTitle
        self.chapterURLString = chapterURLString
        self.sourceKindRaw = sourceKindRaw
        self.openedAt = openedAt
    }
}
