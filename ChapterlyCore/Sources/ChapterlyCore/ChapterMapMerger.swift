import Foundation

public struct ChapterRecord: Equatable {
    public var title: String
    public var urlString: String        // always normalized
    public var visibleDateText: String?
    public var orderIndex: Int

    public init(title: String, urlString: String, visibleDateText: String?, orderIndex: Int) {
        self.title = title
        self.urlString = urlString
        self.visibleDateText = visibleDateText
        self.orderIndex = orderIndex
    }
}

public enum ChapterMapMerger {
    public static func merge(existing: [ChapterRecord],
                             incoming: [ImporterChapterPayload]) -> [ChapterRecord] {
        var result = existing
        var known = Set(existing.map(\.urlString))
        var nextIndex = (existing.map(\.orderIndex).max() ?? -1) + 1

        for candidate in incoming.sorted(by: { $0.domOrder < $1.domOrder }) {
            guard let normalized = URLNormalizer.normalize(candidate.url)?.absoluteString,
                  !known.contains(normalized) else { continue }
            known.insert(normalized)
            result.append(ChapterRecord(title: candidate.title,
                                        urlString: normalized,
                                        visibleDateText: candidate.visibleDateText,
                                        orderIndex: nextIndex))
            nextIndex += 1
        }
        return result
    }
}
