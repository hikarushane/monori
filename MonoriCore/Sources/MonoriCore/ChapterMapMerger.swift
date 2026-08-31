import Foundation

public struct ChapterRecord: Equatable {
    public var title: String
    public var urlString: String        // always normalized
    public var visibleDateText: String?
    public var excerpt: String?
    public var orderIndex: Int

    public init(title: String, urlString: String, visibleDateText: String?,
                excerpt: String? = nil, orderIndex: Int) {
        self.title = title
        self.urlString = urlString
        self.visibleDateText = visibleDateText
        self.excerpt = excerpt
        self.orderIndex = orderIndex
    }
}

public enum ChapterMapMerger {
    public static func merge(existing: [ChapterRecord],
                             incoming: [ImporterChapterPayload]) -> [ChapterRecord] {
        var result = existing
        var incomingURLs = Set<String>()
        var nextIndex = 0

        for candidate in incoming.sorted(by: { $0.domOrder < $1.domOrder }) {
            guard let normalized = URLNormalizer.normalize(candidate.url)?.absoluteString else { continue }
            guard incomingURLs.insert(normalized).inserted else { continue }
            if let index = result.firstIndex(where: { $0.urlString == normalized }) {
                let oldTitle = result[index].title
                if ChapterTextFormatter.isProbablyContaminatedTitle(oldTitle),
                   !ChapterTextFormatter.isProbablyContaminatedTitle(candidate.title) {
                    result[index].title = candidate.title
                }
                if result[index].visibleDateText == nil {
                    result[index].visibleDateText = candidate.visibleDateText
                }
                if result[index].excerpt == nil, let excerpt = candidate.excerpt {
                    result[index].excerpt = excerpt
                }
                result[index].orderIndex = nextIndex
                nextIndex += 1
                continue
            }
            result.append(ChapterRecord(title: candidate.title,
                                        urlString: normalized,
                                        visibleDateText: candidate.visibleDateText,
                                        excerpt: candidate.excerpt,
                                        orderIndex: nextIndex))
            nextIndex += 1
        }

        // Preserve chapters missing from a partial refresh, placing them after
        // the scraped newest-first window without disturbing their prior order.
        let unmatched = result.indices
            .filter { !incomingURLs.contains(result[$0].urlString) }
            .sorted { result[$0].orderIndex < result[$1].orderIndex }
        for index in unmatched {
            result[index].orderIndex = nextIndex
            nextIndex += 1
        }

        return result
    }
}
