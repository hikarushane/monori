import Foundation

public struct CloudBackupMetadata: Sendable {
    public let schemaVersion: Int
    public let createdAt: Date
    public let appVersion: String?
    public let collectionCount: Int
    public let chapterCount: Int
    public let historyCount: Int

    public init(schemaVersion: Int, createdAt: Date, appVersion: String?,
                collectionCount: Int, chapterCount: Int, historyCount: Int) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.collectionCount = collectionCount
        self.chapterCount = chapterCount
        self.historyCount = historyCount
    }
}

public enum CloudBackupError: Error {
    case noBackupFound
    case newerBackupExists(serverDate: Date)
    case noAccount
    case restricted
    case unavailable(Error)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case uploadFailed(Error)
    case downloadFailed(Error)
}

public protocol CloudBackupTransport: Sendable {
    func fetchMetadata() async throws -> CloudBackupMetadata?
    func fetchBackup() async throws -> LibraryBackupEnvelope
    func saveBackup(_ envelope: LibraryBackupEnvelope, overwrite: Bool) async throws
    func deleteBackup() async throws
}
