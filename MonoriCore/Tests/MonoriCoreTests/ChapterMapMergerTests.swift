import XCTest
import MonoriCore

final class ChapterMapMergerTests: XCTestCase {
    private func payload(_ title: String, _ url: String, order: Int,
                         excerpt: String? = nil) -> ImporterChapterPayload {
        ImporterChapterPayload(title: title, url: url, visibleDateText: nil,
                               excerpt: excerpt,
                               collectionName: "焚心", collectionURL: "https://www.patreon.com/collection/9",
                               domOrder: order)
    }

    func testFreshImportUsesDomOrder() {
        let merged = ChapterMapMerger.merge(existing: [], incoming: [
            payload("4 愛", "https://patreon.com/posts/4-2", order: 1),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 2),
            payload("3", "https://patreon.com/posts/3-1", order: 0)
        ])
        XCTAssertEqual(merged.map(\.title), ["3", "4 愛", "5 脣瓣"])
        XCTAssertEqual(merged.map(\.orderIndex), [0, 1, 2])
        XCTAssertEqual(merged[0].urlString, "https://www.patreon.com/posts/3-1")
    }

    func testReimportPreservesManualEditsAndAppendsNew() {
        let existing = [
            ChapterRecord(title: "My renamed title", urlString: "https://www.patreon.com/posts/3-1",
                          visibleDateText: nil, orderIndex: 0),
            ChapterRecord(title: "4 愛", urlString: "https://www.patreon.com/posts/4-2",
                          visibleDateText: nil, orderIndex: 1)
        ]
        let merged = ChapterMapMerger.merge(existing: existing, incoming: [
            payload("3", "https://patreon.com/posts/3-1?utm_source=x", order: 0),
            payload("4 愛", "https://patreon.com/posts/4-2", order: 1),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 2)
        ])
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged[0].title, "My renamed title") // manual rename preserved
        XCTAssertEqual(merged[2].title, "5 脣瓣")
        XCTAssertEqual(merged[2].orderIndex, 2)
    }

    func testReimportRefreshesOrderIndexesFromLatestCollectionOrder() {
        let existing = [
            ChapterRecord(title: "3", urlString: "https://www.patreon.com/posts/3-3",
                          visibleDateText: nil, orderIndex: 0),
            ChapterRecord(title: "2", urlString: "https://www.patreon.com/posts/2-2",
                          visibleDateText: nil, orderIndex: 1),
            ChapterRecord(title: "1", urlString: "https://www.patreon.com/posts/1-1",
                          visibleDateText: nil, orderIndex: 2)
        ]
        let merged = ChapterMapMerger.merge(existing: existing, incoming: [
            payload("4", "https://www.patreon.com/posts/4-4", order: 0),
            payload("3", "https://www.patreon.com/posts/3-3", order: 1),
            payload("2", "https://www.patreon.com/posts/2-2", order: 2),
            payload("1", "https://www.patreon.com/posts/1-1", order: 3)
        ])

        XCTAssertEqual(merged.sorted { $0.orderIndex < $1.orderIndex }.map(\.title),
                       ["4", "3", "2", "1"])
    }

    func testPartialReimportKeepsMissingChaptersAfterScrapedWindow() {
        let existing = [
            ChapterRecord(title: "3", urlString: "https://www.patreon.com/posts/3-3",
                          visibleDateText: nil, orderIndex: 0),
            ChapterRecord(title: "2", urlString: "https://www.patreon.com/posts/2-2",
                          visibleDateText: nil, orderIndex: 1),
            ChapterRecord(title: "1", urlString: "https://www.patreon.com/posts/1-1",
                          visibleDateText: nil, orderIndex: 2)
        ]
        let merged = ChapterMapMerger.merge(existing: existing, incoming: [
            payload("4", "https://www.patreon.com/posts/4-4", order: 0),
            payload("3", "https://www.patreon.com/posts/3-3", order: 1)
        ])
        let indexes = Dictionary(uniqueKeysWithValues: merged.map { ($0.title, $0.orderIndex) })

        XCTAssertEqual(indexes, ["4": 0, "3": 1, "2": 2, "1": 3])
    }

    func testReimportReplacesContaminatedCardTextTitle() {
        let contaminated = """
        FAKE_BODY_TEXT_MUST_NEVER_LEAK 這是一行被 Patreon 卡片連結混進來的內文。
        第二行內文。
        第三行內文。
        """
        let existing = [
            ChapterRecord(title: contaminated, urlString: "https://www.patreon.com/posts/3-1",
                          visibleDateText: nil, orderIndex: 0)
        ]
        let merged = ChapterMapMerger.merge(existing: existing, incoming: [
            payload("真正的文章標題", "https://patreon.com/posts/3-1?utm_source=x", order: 0)
        ])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].title, "真正的文章標題")
    }

    func testReimportFillsMissingExcerptKeepsExisting() {
        let existing = [
            ChapterRecord(title: "A", urlString: "https://www.patreon.com/posts/a-1",
                          visibleDateText: nil, excerpt: nil, orderIndex: 0),
            ChapterRecord(title: "B", urlString: "https://www.patreon.com/posts/b-2",
                          visibleDateText: nil, excerpt: "原有摘要", orderIndex: 1)
        ]
        let merged = ChapterMapMerger.merge(existing: existing, incoming: [
            payload("A", "https://patreon.com/posts/a-1", order: 0, excerpt: "新摘要"),
            payload("B", "https://patreon.com/posts/b-2", order: 1, excerpt: "不該覆蓋")
        ])
        XCTAssertEqual(merged[0].excerpt, "新摘要")
        XCTAssertEqual(merged[1].excerpt, "原有摘要")
    }

    func testDuplicateURLsWithinImportDeduped() {
        let merged = ChapterMapMerger.merge(existing: [], incoming: [
            payload("A", "https://patreon.com/posts/a-1", order: 0),
            payload("A again", "https://patreon.com/posts/a-1/", order: 1)
        ])
        XCTAssertEqual(merged.count, 1)
    }

    func testUnnormalizableURLSkipped() {
        let merged = ChapterMapMerger.merge(existing: [], incoming: [
            payload("evil", "https://example.com/posts/x", order: 0),
            payload("ok", "https://patreon.com/posts/ok-1", order: 1)
        ])
        XCTAssertEqual(merged.map(\.title), ["ok"])
    }
}
