import XCTest
@testable import MonoriCore

final class ChapterOrderingTests: XCTestCase {
    func testPatreonKeyUsesCollectionPositionWhenPostIDsConflict() {
        // In Patreon collection 2299876, chapter 12 appears before chapter 13
        // even though chapter 12 has the larger post ID.
        let older = ChapterOrdering.sortKey(
            urlString: "https://www.patreon.com/posts/166006471?collection=2299876",
            orderIndex: 9)
        let newer = ChapterOrdering.sortKey(
            urlString: "https://www.patreon.com/posts/165978296?collection=2299876",
            orderIndex: 8)
        XCTAssertTrue(older < newer)
    }

    func testPatreonKeyReversesNewestFirstCollectionPosition() {
        let key = ChapterOrdering.sortKey(urlString: "https://www.patreon.com/posts/chapter-title-160628832",
                                          orderIndex: 5)
        XCTAssertEqual(key.0, 0)
        XCTAssertEqual(key.1, -5)
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
