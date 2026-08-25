import Foundation
import XCTest
@testable import MonoriCore

final class ReadingHistoryQueryTests: XCTestCase {

    private func entry(openedAt: Date, chapterTitle: String = "ch") -> LocalReadingHistoryEntry {
        LocalReadingHistoryEntry(
            collectionID: "c1", chapterID: UUID().uuidString,
            collectionTitle: "col", chapterTitle: chapterTitle,
            chapterURLString: "https://example.com/\(chapterTitle)",
            sourceKindRaw: "patreon", openedAt: openedAt)
    }

    private func calendar(timeZone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    func testSameDayEntriesGroupIntoOneSection() {
        let cal = calendar(timeZone: TimeZone(identifier: "Asia/Taipei")!)
        let base = cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 14))!
        let e1 = entry(openedAt: base, chapterTitle: "a")
        let e2 = entry(openedAt: base.addingTimeInterval(3600), chapterTitle: "b")

        let sections = ReadingHistoryQuery.sections(from: [e1, e2], calendar: cal)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].entries.count, 2)
    }

    func testCrossMidnightSplitsIntoTwoSections() {
        let cal = calendar(timeZone: TimeZone(identifier: "Asia/Taipei")!)
        let beforeMidnight = cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 23, minute: 50))!
        let afterMidnight = cal.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 0, minute: 10))!

        let sections = ReadingHistoryQuery.sections(
            from: [entry(openedAt: beforeMidnight), entry(openedAt: afterMidnight)],
            calendar: cal)
        XCTAssertEqual(sections.count, 2)
    }

    func testSectionsOrderedNewestFirst() {
        let cal = calendar(timeZone: TimeZone(identifier: "Asia/Taipei")!)
        let day1 = cal.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 10))!
        let day2 = cal.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 10))!
        let day3 = cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 10))!

        let sections = ReadingHistoryQuery.sections(
            from: [entry(openedAt: day1), entry(openedAt: day2), entry(openedAt: day3)],
            calendar: cal)
        XCTAssertEqual(sections.count, 3)
        XCTAssertTrue(sections[0].day > sections[1].day)
        XCTAssertTrue(sections[1].day > sections[2].day)
    }

    func testEntriesWithinSectionOrderedNewestFirst() {
        let cal = calendar(timeZone: TimeZone(identifier: "Asia/Taipei")!)
        let t1 = cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 10))!
        let t2 = cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 14))!
        let t3 = cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 18))!

        let sections = ReadingHistoryQuery.sections(
            from: [entry(openedAt: t1, chapterTitle: "early"),
                   entry(openedAt: t3, chapterTitle: "late"),
                   entry(openedAt: t2, chapterTitle: "mid")],
            calendar: cal)
        XCTAssertEqual(sections[0].entries.map(\.chapterTitle), ["late", "mid", "early"])
    }

    func testNonUTCTimezoneGroupsByLocalDay() {
        let utc = calendar(timeZone: .gmt)
        let taipei = calendar(timeZone: TimeZone(identifier: "Asia/Taipei")!)
        // 2026-08-25 23:30 UTC = 2026-08-26 07:30 Taipei
        let date = utc.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 23, minute: 30))!

        let utcSections = ReadingHistoryQuery.sections(from: [entry(openedAt: date)], calendar: utc)
        let taipeiSections = ReadingHistoryQuery.sections(from: [entry(openedAt: date)], calendar: taipei)

        let utcDay = utc.component(.day, from: utcSections[0].day)
        let taipeiDay = taipei.component(.day, from: taipeiSections[0].day)
        XCTAssertEqual(utcDay, 25)
        XCTAssertEqual(taipeiDay, 26)
    }

    func testDSTBoundaryDoesNotUseFixed24Hours() {
        // US Eastern: 2026-03-08 spring forward at 02:00
        guard let eastern = TimeZone(identifier: "America/New_York") else { return }
        let cal = calendar(timeZone: eastern)
        // 2026-03-07 23:00 ET and 2026-03-08 01:00 ET (same night, DST transition day)
        let beforeDST = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23))!
        let afterDST = cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1))!

        let sections = ReadingHistoryQuery.sections(
            from: [entry(openedAt: beforeDST), entry(openedAt: afterDST)],
            calendar: cal)
        XCTAssertEqual(sections.count, 2, "DST boundary should split by calendar day, not 24h")
    }

    func testEmptyInputReturnsEmptySections() {
        let sections = ReadingHistoryQuery.sections(from: [])
        XCTAssertTrue(sections.isEmpty)
    }
}
