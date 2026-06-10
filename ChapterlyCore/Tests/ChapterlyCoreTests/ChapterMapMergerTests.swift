import XCTest
import ChapterlyCore

final class ChapterMapMergerTests: XCTestCase {
    private func payload(_ title: String, _ url: String, order: Int) -> ImporterChapterPayload {
        ImporterChapterPayload(title: title, url: url, visibleDateText: nil,
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
