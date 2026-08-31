import Foundation

/// Canonical chapter ordering for a collection.
///
/// Patreon collection cards are scraped newest-first, so a larger `orderIndex`
/// is older. Post IDs cannot be used as publish order: creators can prepare
/// posts out of sequence, making IDs conflict with the collection order.
/// Vocus article IDs retain their timestamp-based ordering. Other sources fall
/// back to their native oldest-first `orderIndex`.
public enum ChapterOrdering {
    /// Ascending publish-order key. Compare with `<`: a smaller key is older.
    /// The first element is a source-specific bucket; the second is its ordering
    /// value normalized to oldest → newest.
    public static func sortKey(urlString: String, orderIndex: Int) -> (Int, Int) {
        if URLNormalizer.patreonPostID(urlString) != nil {
            return (0, -orderIndex)
        }
        if let hex = URLNormalizer.vocusArticleID(urlString),
           let ts = Int(hex.prefix(8), radix: 16) {
            return (0, ts)
        }
        return (1, orderIndex)
    }
}
