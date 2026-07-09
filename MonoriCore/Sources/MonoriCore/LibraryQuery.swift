import Foundation

public enum LibrarySortOrder: String, CaseIterable, Sendable {
    case title
    case recentlyUpdated
    case recentlyRead
}

public enum LibraryQuery {
    /// Filter + sort for the Library list. Runs in memory: personal libraries
    /// are tens of collections, not thousands.
    public static func apply(_ collections: [LocalCollectionModel],
                             sort: LibrarySortOrder,
                             searchText: String,
                             status: CollectionReadingStatus?) -> [LocalCollectionModel] {
        var result = collections
        if let status {
            result = result.filter { $0.readingStatus == status }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || ($0.creatorName?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        switch sort {
        case .title:
            return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .recentlyUpdated:
            return result.sorted { ($0.lastNewChapterAt ?? .distantPast) > ($1.lastNewChapterAt ?? .distantPast) }
        case .recentlyRead:
            return result.sorted { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) }
        }
    }
}
