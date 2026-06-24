import Foundation
import SwiftData

public enum CollectionSortDirection: String, Codable {
    case oldestToNewest
    case newestToOldest
}

@Model
public final class LocalCollectionModel {
    @Attribute(.unique) public var id: String
    public var title: String
    public var sourceURLString: String        // normalized
    public var creatorName: String?
    public var sortDirectionRaw: String
    public var sourceKindRaw: String = SourceKind.patreon.rawValue
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
    public var contentHTML: String?
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
