import XCTest
import SwiftData
@testable import ChapterlyCore

final class ModelMigrationTests: XCTestCase {
    @MainActor
    func testDefaultsForNewFields() throws {
        let store = try LibraryStore.inMemory()
        let c = LocalCollectionModel(title: "X", sourceURLString: "https://www.patreon.com/c/x")
        let ch = LocalChapterModel(title: "Ch", urlString: "https://www.patreon.com/posts/1", orderIndex: 0)
        XCTAssertEqual(c.sourceKind, .patreon)
        XCTAssertNil(ch.contentHTML)
        _ = store
    }

    func testGoogleDocsCollectionRoundTrips() throws {
        let c = LocalCollectionModel(title: "Doc", sourceURLString: "https://docs.google.com/document/d/abc",
                                     sourceKind: .googleDocs)
        XCTAssertEqual(c.sourceKind, .googleDocs)
        c.sourceKind = .patreon
        XCTAssertEqual(c.sourceKindRaw, "patreon")
    }
}
