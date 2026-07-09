import Foundation
import XCTest
import SwiftData
@testable import MonoriCore

@MainActor
final class LibraryQueryTests: XCTestCase {
    private var store: LibraryStore!

    override func setUp() async throws {
        store = try LibraryStore.inMemory()
    }

    private func makeCollection(title: String, creator: String? = nil,
                                url: String) throws -> LocalCollectionModel {
        try store.applyDocImport(ImportedCollection(
            sourceURLString: url, title: title, creatorName: creator, sourceKind: .vocus,
            chapters: [ImportedChapter(title: "c1", urlString: url + "/1", orderIndex: 0)]))
        return try store.collections().first { $0.sourceURLString == url }!
    }

    func testSortByRecentlyUpdatedPutsNilLast() throws {
        let a = try makeCollection(title: "A", url: "https://vocus.cc/room/a")
        let b = try makeCollection(title: "B", url: "https://vocus.cc/room/b")
        b.lastNewChapterAt = Date()
        let sorted = LibraryQuery.apply([a, b], sort: .recentlyUpdated, searchText: "", status: nil)
        XCTAssertEqual(sorted.map(\.title), ["B", "A"])
    }

    func testSortByRecentlyRead() throws {
        let a = try makeCollection(title: "A", url: "https://vocus.cc/room/a")
        let b = try makeCollection(title: "B", url: "https://vocus.cc/room/b")
        a.lastReadAt = Date(timeIntervalSinceNow: -100)
        b.lastReadAt = Date()
        let sorted = LibraryQuery.apply([a, b], sort: .recentlyRead, searchText: "", status: nil)
        XCTAssertEqual(sorted.map(\.title), ["B", "A"])
    }

    func testSearchMatchesTitleAndCreatorCaseInsensitive() throws {
        let a = try makeCollection(title: "焚心", creator: "Ocean", url: "https://vocus.cc/room/a")
        _ = try makeCollection(title: "另一部", creator: "someone", url: "https://vocus.cc/room/b")
        let all = try store.collections()
        XCTAssertEqual(LibraryQuery.apply(all, sort: .title, searchText: "焚", status: nil).map(\.id), [a.id])
        XCTAssertEqual(LibraryQuery.apply(all, sort: .title, searchText: "ocean", status: nil).map(\.id), [a.id])
        XCTAssertTrue(LibraryQuery.apply(all, sort: .title, searchText: "沒有這個", status: nil).isEmpty)
    }

    func testStatusFilter() throws {
        let a = try makeCollection(title: "A", url: "https://vocus.cc/room/a")
        let b = try makeCollection(title: "B", url: "https://vocus.cc/room/b")
        b.readingStatus = .finished
        let all = [a, b]
        XCTAssertEqual(LibraryQuery.apply(all, sort: .title, searchText: "", status: .finished).map(\.id), [b.id])
        XCTAssertEqual(LibraryQuery.apply(all, sort: .title, searchText: "", status: nil).count, 2)
    }
}
