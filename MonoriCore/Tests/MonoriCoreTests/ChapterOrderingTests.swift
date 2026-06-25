import XCTest
@testable import MonoriCore

final class ChapterOrderingTests: XCTestCase {
    func testKeyOrdersByPostIDAscendingRegardlessOfOrderIndex() {
        // Older post (smaller ID) must sort before a newer post even when the
        // scrape-time orderIndex says the opposite.
        let older = ChapterOrdering.sortKey(urlString: "https://www.patreon.com/posts/intro-100",
                                            orderIndex: 99)
        let newer = ChapterOrdering.sortKey(urlString: "https://www.patreon.com/posts/c17-117",
                                            orderIndex: 0)
        XCTAssertTrue(older < newer)
    }

    func testKeyExtractsTrailingNumericPostID() {
        let key = ChapterOrdering.sortKey(urlString: "https://www.patreon.com/posts/chapter-title-160628832",
                                          orderIndex: 5)
        XCTAssertEqual(key.0, 0)            // bucket 0 == has a post ID
        XCTAssertEqual(key.1, 160628832)
    }

    func testKeyWithoutPostIDFallsBackAndSortsLast() {
        let withID = ChapterOrdering.sortKey(urlString: "https://www.patreon.com/posts/c1-101",
                                             orderIndex: 0)
        let withoutID = ChapterOrdering.sortKey(urlString: "https://www.patreon.com/collection/9",
                                                orderIndex: 0)
        XCTAssertEqual(withoutID.0, 1)     // bucket 1 == fallback
        XCTAssertTrue(withID < withoutID)  // ID-bearing chapters sort ahead of ID-less ones
    }

    func testVocusKeyOrdersByArticleIDAscending() {
        // Older article (smaller hex ID prefix) must sort before newer article
        // regardless of orderIndex.
        let older = ChapterOrdering.sortKey(
            urlString: "https://vocus.cc/article/65a4a22bfd89780001e7867a",
            orderIndex: 99)
        let newer = ChapterOrdering.sortKey(
            urlString: "https://vocus.cc/article/6a2f7074fd89780001b35add",
            orderIndex: 0)
        XCTAssertTrue(older < newer)
    }

    func testVocusKeyUsesArticleIDBucket() {
        let key = ChapterOrdering.sortKey(
            urlString: "https://vocus.cc/article/67ca7699fd897800017f312c",
            orderIndex: 5)
        XCTAssertEqual(key.0, 0)  // bucket 0 == has a sortable ID
    }

    func testVocusKeyBeatsIDLessChapter() {
        let withID = ChapterOrdering.sortKey(
            urlString: "https://vocus.cc/article/67ca7699fd897800017f312c",
            orderIndex: 0)
        let withoutID = ChapterOrdering.sortKey(
            urlString: "https://vocus.cc/salon/Aliens/room/abc",
            orderIndex: 0)
        XCTAssertTrue(withID < withoutID)
    }
}
