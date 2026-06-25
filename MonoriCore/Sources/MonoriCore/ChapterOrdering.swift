import Foundation

/// Canonical chapter ordering for a collection.
///
/// Chapters used to be ordered by `orderIndex` — the position a post happened to
/// occupy while the collection page was scraped. That order is fragile: on a
/// re-import the newly published posts are appended after the existing maximum
/// `orderIndex` in DOM order, so a "newest first" Patreon list lands the newest
/// chapter *before* the older new ones, and `orderedChapters` (which treated
/// index 0 as oldest) and `neighbors` (which treated index 0 as newest)
/// disagreed about direction.
///
/// Patreon post IDs increase monotonically with publish time, so they give a
/// stable publish order that is immune to scrape direction and re-import timing
/// and matches the reader's expectation ("sort by real publish date"). We sort
/// by post ID ascending == oldest → newest. Chapters whose URL carries no
/// numeric post ID fall back to their `orderIndex` and sort *after* every
/// ID-bearing chapter so they never interleave unpredictably.
public enum ChapterOrdering {
    /// Ascending publish-order key. Compare with `<`: a smaller key is older.
    /// The first element is a bucket (0 == has a post ID, 1 == fallback) so
    /// ID-less chapters always sort last; the second element is the numeric post
    /// ID, or the `orderIndex` for the fallback bucket.
    public static func sortKey(urlString: String, orderIndex: Int) -> (Int, Int) {
        if let id = URLNormalizer.patreonPostID(urlString).flatMap(Int.init) {
            return (0, id)
        }
        if let hex = URLNormalizer.vocusArticleID(urlString),
           let ts = Int(hex.prefix(8), radix: 16) {
            return (0, ts)
        }
        return (1, orderIndex)
    }
}
