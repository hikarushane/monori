import Foundation
import CloudKit
import MonoriCore

final class CloudKitBackupTransport: CloudBackupTransport, @unchecked Sendable {
    private let containerID: String
    private var container: CKContainer { CKContainer(identifier: containerID) }
    private var database: CKDatabase { container.privateCloudDatabase }

    private static let recordType = "MonoriBackup"
    private static let recordName = "primary-v1"
    private static let zoneID = CKRecordZone.ID(zoneName: "_defaultZone", ownerName: CKCurrentUserDefaultName)

    init(containerID: String) {
        self.containerID = containerID
    }

    private var recordID: CKRecord.ID {
        CKRecord.ID(recordName: Self.recordName, zoneID: Self.zoneID)
    }

    func fetchMetadata() async throws -> CloudBackupMetadata? {
        try await checkAccountStatus()
        do {
            let record = try await database.record(for: recordID)
            return metadataFromRecord(record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func fetchBackup() async throws -> LibraryBackupEnvelope {
        try await checkAccountStatus()
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            throw CloudBackupError.noBackupFound
        } catch {
            throw CloudBackupError.downloadFailed(error)
        }
        guard let asset = record["payload"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw CloudBackupError.noBackupFound
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(LibraryBackupEnvelope.self, from: data)
        } catch {
            throw CloudBackupError.decodingFailed(error)
        }
    }

    func saveBackup(_ envelope: LibraryBackupEnvelope, overwrite: Bool) async throws {
        try await checkAccountStatus()

        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            data = try encoder.encode(envelope)
        } catch {
            throw CloudBackupError.encodingFailed(error)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("monori-backup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try data.write(to: tempURL)

        if !overwrite {
            if let existing = try? await database.record(for: recordID) {
                if let serverDate = existing["createdAt"] as? Date,
                   serverDate > envelope.createdAt {
                    throw CloudBackupError.newerBackupExists(serverDate: serverDate)
                }
            }
        }

        let record: CKRecord
        if let existing = try? await database.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }

        record["schemaVersion"] = envelope.schemaVersion as NSNumber
        record["createdAt"] = envelope.createdAt as NSDate
        record["appVersion"] = envelope.appVersion as NSString?
        record["collectionCount"] = envelope.collectionCount as NSNumber
        record["chapterCount"] = envelope.chapterCount as NSNumber
        record["historyCount"] = envelope.historyCount as NSNumber
        record["payload"] = CKAsset(fileURL: tempURL)

        do {
            try await database.save(record)
        } catch {
            throw CloudBackupError.uploadFailed(error)
        }
    }

    func deleteBackup() async throws {
        try await checkAccountStatus()
        do {
            try await database.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw CloudBackupError.downloadFailed(error)
        }
    }

    private func checkAccountStatus() async throws {
        let status = try await container.accountStatus()
        switch status {
        case .available: return
        case .noAccount: throw CloudBackupError.noAccount
        case .restricted: throw CloudBackupError.restricted
        default: throw CloudBackupError.unavailable(
            NSError(domain: "CloudKit", code: Int(status.rawValue)))
        }
    }

    private func metadataFromRecord(_ record: CKRecord) -> CloudBackupMetadata {
        CloudBackupMetadata(
            schemaVersion: (record["schemaVersion"] as? Int) ?? 1,
            createdAt: (record["createdAt"] as? Date) ?? record.creationDate ?? .distantPast,
            appVersion: record["appVersion"] as? String,
            collectionCount: (record["collectionCount"] as? Int) ?? 0,
            chapterCount: (record["chapterCount"] as? Int) ?? 0,
            historyCount: (record["historyCount"] as? Int) ?? 0)
    }
}
