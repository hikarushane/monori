import XCTest
@testable import ChapterlyCore

final class ScriptMessageRouterTests: XCTestCase {
    func testRoutesValidImporterMessage() {
        var received: [ImporterChapterPayload] = []
        let router = ScriptMessageRouter()
        router.onImporterChapter = { received.append($0) }
        router.route(name: ScriptMessageRouter.importName, body: [
            "title": "4 愛", "url": "https://patreon.com/posts/4-2",
            "visibleDateText": NSNull(),
            "collectionName": "焚心", "collectionURL": "https://patreon.com/collection/9",
            "domOrder": 0
        ] as [String: Any])
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(router.rejectedCount, 0)
    }

    func testRejectsAndCountsForbiddenPayload() {
        var received: [ImporterChapterPayload] = []
        let router = ScriptMessageRouter()
        router.onImporterChapter = { received.append($0) }
        router.route(name: ScriptMessageRouter.importName, body: [
            "title": "x", "url": "https://patreon.com/posts/x",
            "collectionName": "c", "collectionURL": "https://patreon.com/collection/9",
            "domOrder": 0, "innerHTML": "<p>steal</p>"
        ] as [String: Any])
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(router.rejectedCount, 1)
        XCTAssertEqual(router.lastRejectedReason, "forbiddenKey_innerhtml")
    }

    func testRoutesCollectionLink() {
        var links: [CollectionLinkPayload] = []
        let router = ScriptMessageRouter()
        router.onCollectionLink = { links.append($0) }
        router.route(name: ScriptMessageRouter.collectionLinkName,
                     body: ["collectionName": "焚心",
                            "collectionURL": "https://patreon.com/collection/9"] as [String: Any])
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(router.rejectedCount, 0)
    }

    func testUnknownHandlerNameIgnored() {
        let router = ScriptMessageRouter()
        router.route(name: "somethingElse", body: ["a": 1])
        XCTAssertEqual(router.rejectedCount, 1)
        XCTAssertEqual(router.lastRejectedReason, "unknown_handler")
    }
}
