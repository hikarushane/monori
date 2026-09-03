import Foundation

public enum LibrarySortOrder: String, CaseIterable, Sendable {
    case title
    case recentlyUpdated
    case recentlyRead
    case source
    case author
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
        case .source:
            return result.sorted {
                let s0 = $0.sourceKind.rawValue
                let s1 = $1.sourceKind.rawValue
                if s0 != s1 { return s0 < s1 }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .author:
            return result.sorted {
                let a = $0.creatorName ?? ""
                let b = $1.creatorName ?? ""
                if a.isEmpty != b.isEmpty { return !a.isEmpty }
                if a != b { return a.localizedStandardCompare(b) == .orderedAscending }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }
}
