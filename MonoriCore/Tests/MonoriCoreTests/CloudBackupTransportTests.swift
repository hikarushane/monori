import Foundation
import XCTest
@testable import MonoriCore

final class InMemoryBackupTransport: CloudBackupTransport, @unchecked Sendable {
    var stored: LibraryBackupEnvelope?
    var shouldFailWith: CloudBackupError?
    var saveCount = 0

    func fetchMetadata() async throws -> CloudBackupMetadata? {
        if let error = shouldFailWith { throw error }
        guard let s = stored else { return nil }
        return CloudBackupMetadata(
            schemaVersion: s.schemaVersion, createdAt: s.createdAt,
            appVersion: s.appVersion, collectionCount: s.collectionCount,
            chapterCount: s.chapterCount, historyCount: s.historyCount)
    }

    func fetchBackup() async throws -> LibraryBackupEnvelope {
        if let error = shouldFailWith { throw error }
        guard let s = stored else { throw CloudBackupError.noBackupFound }
        return s
    }

    func saveBackup(_ envelope: LibraryBackupEnvelope, overwrite: Bool) async throws {
        if let error = shouldFailWith { throw error }
        if !overwrite, let existing = stored, existing.createdAt > envelope.createdAt {
            throw CloudBackupError.newerBackupExists(serverDate: existing.createdAt)
        }
        stored = envelope
        saveCount += 1
    }

    func deleteBackup() async throws {
        if let error = shouldFailWith { throw error }
        stored = nil
    }
}

@MainActor
final class CloudBackupTransportTests: XCTestCase {
    private var store: LibraryStore!
    private var transport: InMemoryBackupTransport!

    override func setUp() async throws {
        store = try LibraryStore.inMemory()
        transport = InMemoryBackupTransport()
    }

    private func seedOneCollection() throws {
        let imported = ImportedCollection(
            sourceURLString: "https://patreon.com/collection/1",
            title: "Story", creatorName: "Author", sourceKind: .patreon,
            chapters: [ImportedChapter(title: "Ch1", urlString: "https://patreon.com/posts/1", orderIndex: 0)])
        try store.applyDocImport(imported)
    }

    func testNoBackupReturnsNilMetadata() async throws {
        let meta = try await transport.fetchMetadata()
        XCTAssertNil(meta)
    }

    func testBackupAndFetchRoundTrip() async throws {
        try seedOneCollection()
        let snapshot = try store.makeBackupSnapshot()
        try await transport.saveBackup(snapshot, overwrite: false)

        let fetched = try await transport.fetchBackup()
        XCTAssertEqual(fetched.collectionCount, 1)
        XCTAssertEqual(fetched.chapterCount, 1)
    }

    func testFetchWithNoBackupThrows() async throws {
        do {
            _ = try await transport.fetchBackup()
            XCTFail("Expected noBackupFound")
        } catch let error as CloudBackupError {
            if case .noBackupFound = error { } else {
                XCTFail("Expected noBackupFound, got \(error)")
            }
        }
    }

    func testNewerServerConflict() async throws {
        try seedOneCollection()
        let newer = try store.makeBackupSnapshot(now: Date.now.addingTimeInterval(3600))
        try await transport.saveBackup(newer, overwrite: false)

        let older = try store.makeBackupSnapshot(now: Date.now.addingTimeInterval(-3600))
        do {
            try await transport.saveBackup(older, overwrite: false)
            XCTFail("Expected newerBackupExists")
        } catch let error as CloudBackupError {
            if case .newerBackupExists = error { } else {
                XCTFail("Expected newerBackupExists, got \(error)")
            }
        }
    }

    func testForceOverwriteIgnoresConflict() async throws {
        try seedOneCollection()
        let newer = try store.makeBackupSnapshot(now: Date.now.addingTimeInterval(3600))
        try await transport.saveBackup(newer, overwrite: false)

        let older = try store.makeBackupSnapshot(now: Date.now.addingTimeInterval(-3600))
        try await transport.saveBackup(older, overwrite: true)
        XCTAssertEqual(transport.saveCount, 2)
    }

    func testUploadErrorPassesThrough() async throws {
        transport.shouldFailWith = .uploadFailed(
            NSError(domain: "test", code: 1))
        try seedOneCollection()
        let snapshot = try store.makeBackupSnapshot()
        do {
            try await transport.saveBackup(snapshot, overwrite: false)
            XCTFail("Expected uploadFailed")
        } catch let error as CloudBackupError {
            if case .uploadFailed = error { } else {
                XCTFail("Expected uploadFailed, got \(error)")
            }
        }
    }

    func testDownloadErrorPassesThrough() async throws {
        transport.shouldFailWith = .downloadFailed(
            NSError(domain: "test", code: 2))
        do {
            _ = try await transport.fetchBackup()
            XCTFail("Expected downloadFailed")
        } catch let error as CloudBackupError {
            if case .downloadFailed = error { } else {
                XCTFail("Expected downloadFailed, got \(error)")
            }
        }
    }

    func testNoAccountErrorPassesThrough() async throws {
        transport.shouldFailWith = .noAccount
        do {
            _ = try await transport.fetchMetadata()
            XCTFail("Expected noAccount")
        } catch let error as CloudBackupError {
            if case .noAccount = error { } else {
                XCTFail("Expected noAccount, got \(error)")
            }
        }
    }

    func testDeleteRemovesBackup() async throws {
        try seedOneCollection()
        let snapshot = try store.makeBackupSnapshot()
        try await transport.saveBackup(snapshot, overwrite: false)
        let before = try await transport.fetchMetadata()
        XCTAssertNotNil(before)

        try await transport.deleteBackup()
        let after = try await transport.fetchMetadata()
        XCTAssertNil(after)
    }
}
