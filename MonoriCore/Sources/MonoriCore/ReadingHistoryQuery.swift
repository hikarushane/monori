import Foundation

public struct ReadingHistoryDaySection {
    public let day: Date
    public let entries: [LocalReadingHistoryEntry]
}

public enum ReadingHistoryQuery {
    public static func sections(
        from entries: [LocalReadingHistoryEntry],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [ReadingHistoryDaySection] {
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.openedAt)
        }
        return grouped
            .map { ReadingHistoryDaySection(day: $0.key, entries: $0.value.sorted { $0.openedAt > $1.openedAt }) }
            .sorted { $0.day > $1.day }
    }
}
