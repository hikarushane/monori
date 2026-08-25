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

    func testStatusFilterReturnsOnlyMatchingStatus() throws {
        let reading = try makeCollection(title: "Reading", url: "https://vocus.cc/room/r")
        let finished = try makeCollection(title: "Finished", url: "https://vocus.cc/room/f")
        let dropped = try makeCollection(title: "Dropped", url: "https://vocus.cc/room/d")
        finished.readingStatus = .finished
        dropped.readingStatus = .dropped
        let all = [reading, finished, dropped]

        let readingResult = LibraryQuery.apply(all, sort: .title, searchText: "", status: .reading)
        XCTAssertEqual(readingResult.map(\.title), ["Reading"])

        let finishedResult = LibraryQuery.apply(all, sort: .title, searchText: "", status: .finished)
        XCTAssertEqual(finishedResult.map(\.title), ["Finished"])

        let droppedResult = LibraryQuery.apply(all, sort: .title, searchText: "", status: .dropped)
        XCTAssertEqual(droppedResult.map(\.title), ["Dropped"])
    }

    func testStatusFilterCombinesWithSearch() throws {
        let a = try makeCollection(title: "焚心", creator: "Ocean", url: "https://vocus.cc/room/a")
        let b = try makeCollection(title: "焚心外傳", url: "https://vocus.cc/room/b")
        b.readingStatus = .finished
        let all = [a, b]

        let result = LibraryQuery.apply(all, sort: .title, searchText: "焚心", status: .reading)
        XCTAssertEqual(result.map(\.id), [a.id])

        let finishedSearch = LibraryQuery.apply(all, sort: .title, searchText: "焚心", status: .finished)
        XCTAssertEqual(finishedSearch.map(\.id), [b.id])
    }

    func testEmptyStatusScopeReturnsEmpty() throws {
        let a = try makeCollection(title: "A", url: "https://vocus.cc/room/a")
        let all = [a]
        XCTAssertTrue(LibraryQuery.apply(all, sort: .title, searchText: "", status: .finished).isEmpty)
        XCTAssertTrue(LibraryQuery.apply(all, sort: .title, searchText: "", status: .dropped).isEmpty)
    }
}
