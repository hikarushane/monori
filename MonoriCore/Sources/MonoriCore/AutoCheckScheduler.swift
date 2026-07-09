import Foundation

public enum AutoCheckScheduler {
    public static let cooldown: TimeInterval = 6 * 60 * 60

    /// Collections due for a new-chapter check: actively followed,
    /// refresh-capable, and past the cooldown (or never checked).
    /// `force` (pull-to-refresh) ignores the cooldown only.
    public static func due(from collections: [LocalCollectionModel],
                           now: Date = .now,
                           force: Bool = false) -> [LocalCollectionModel] {
        collections.filter { collection in
            guard collection.readingStatus == .reading,
                  collection.sourceKind.supportsAutoCheck else { return false }
            if force { return true }
            guard let last = collection.lastCheckedAt else { return true }
            return now.timeIntervalSince(last) >= cooldown
        }
    }
}
