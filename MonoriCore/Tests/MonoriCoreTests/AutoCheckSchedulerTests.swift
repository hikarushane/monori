import Foundation
import XCTest
import SwiftData
@testable import MonoriCore

@MainActor
final class AutoCheckSchedulerTests: XCTestCase {
    private var store: LibraryStore!

    override func setUp() async throws {
        store = try LibraryStore.inMemory()
    }

    private func makeCollection(url: String, kind: SourceKind = .patreon) throws -> LocalCollectionModel {
        try store.applyDocImport(ImportedCollection(
            sourceURLString: url, title: url, creatorName: nil, sourceKind: kind,
            chapters: [ImportedChapter(title: "c1", urlString: url + "/1", orderIndex: 0)]))
        return try store.collections().first { $0.sourceURLString == url }!
    }

    func testNeverCheckedReadingPatreonCollectionIsDue() throws {
        let c = try makeCollection(url: "https://www.patreon.com/collection/1")
        XCTAssertEqual(AutoCheckScheduler.due(from: [c]).map(\.id), [c.id])
    }

    func testCooldownExcludesRecentlyChecked() throws {
        let c = try makeCollection(url: "https://www.patreon.com/collection/1")
        let now = Date()
        c.lastCheckedAt = now.addingTimeInterval(-5 * 60 * 60)   // 5 h ago
        XCTAssertTrue(AutoCheckScheduler.due(from: [c], now: now).isEmpty)
        c.lastCheckedAt = now.addingTimeInterval(-7 * 60 * 60)   // 7 h ago
        XCTAssertEqual(AutoCheckScheduler.due(from: [c], now: now).count, 1)
    }

    func testForceIgnoresCooldownButNotStatusOrCapability() throws {
        let c = try makeCollection(url: "https://www.patreon.com/collection/1")
        c.lastCheckedAt = Date()
        XCTAssertEqual(AutoCheckScheduler.due(from: [c], force: true).count, 1)
        c.readingStatus = .finished
        XCTAssertTrue(AutoCheckScheduler.due(from: [c], force: true).isEmpty)
    }

    func testNonReadingAndUnsupportedKindsAreExcluded() throws {
        let finished = try makeCollection(url: "https://www.patreon.com/collection/1")
        finished.readingStatus = .finished
        let dropped = try makeCollection(url: "https://www.patreon.com/collection/2")
        dropped.readingStatus = .dropped
        let gdocs = try makeCollection(url: "https://docs.google.com/document/d/x", kind: .googleDocs)
        XCTAssertTrue(AutoCheckScheduler.due(from: [finished, dropped, gdocs]).isEmpty)
    }
}
