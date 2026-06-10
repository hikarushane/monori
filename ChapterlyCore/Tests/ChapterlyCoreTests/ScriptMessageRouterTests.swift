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
    }

    func testRoutesProgressAndCollectionLink() {
        var progress: [ProgressPayload] = []
        var links: [CollectionLinkPayload] = []
        let router = ScriptMessageRouter()
        router.onProgress = { progress.append($0) }
        router.onCollectionLink = { links.append($0) }
        router.route(name: ScriptMessageRouter.progressName,
                     body: ["url": "https://patreon.com/posts/x", "scrollProgress": 0.3] as [String: Any])
        router.route(name: ScriptMessageRouter.collectionLinkName,
                     body: ["collectionName": "焚心",
                            "collectionURL": "https://patreon.com/collection/9"] as [String: Any])
        XCTAssertEqual(progress.count, 1)
        XCTAssertEqual(links.count, 1)
    }

    func testUnknownHandlerNameIgnored() {
        let router = ScriptMessageRouter()
        router.route(name: "somethingElse", body: ["a": 1])
        XCTAssertEqual(router.rejectedCount, 1)
    }
}
