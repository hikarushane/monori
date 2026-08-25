import Foundation
import MonoriCore

@MainActor
@Observable
final class ICloudBackupService {
    enum State: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case unavailable
        case backingUp
        case restoring

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.checking, .checking),
                 (.available, .available),
                 (.noAccount, .noAccount),
                 (.restricted, .restricted),
                 (.unavailable, .unavailable),
                 (.backingUp, .backingUp),
                 (.restoring, .restoring): return true
            default: return false
            }
        }
    }

    enum BackupResult {
        case success
        case newerBackupExists(serverDate: Date)
        case failed(BackupError)
    }

    enum RestoreResult {
        case success
        case noBackup
        case failed(BackupError)
    }

    enum BackupError {
        case noAccount
        case encoding
        case network(String)
        case unknown(String)

        var localizedMessage: String {
            switch self {
            case .noAccount: return "尚未登入 iCloud"
            case .encoding: return "備份資料編碼失敗"
            case .network(let detail): return "iCloud 暫時無法使用：\(detail)"
            case .unknown(let detail): return "備份失敗：\(detail)"
            }
        }
    }

    private(set) var state: State = .checking
    private(set) var lastBackupMetadata: CloudBackupMetadata?
    private(set) var lastError: BackupError?

    private let transport: CloudBackupTransport
    private let store: LibraryStore

    init(transport: CloudBackupTransport, store: LibraryStore) {
        self.transport = transport
        self.store = store
    }

    func checkAvailability() async {
        state = .checking
        do {
            lastBackupMetadata = try await transport.fetchMetadata()
            state = .available
        } catch let error as CloudBackupError {
            switch error {
            case .noAccount:
                state = .noAccount
            case .restricted:
                state = .restricted
            default:
                state = .unavailable
            }
        } catch {
            state = .unavailable
        }
    }

    func backup() async -> BackupResult {
        guard state == .available else { return .failed(.noAccount) }
        state = .backingUp
        defer { if state == .backingUp { state = .available } }
        do {
            let snapshot = try store.makeBackupSnapshot()
            try await transport.saveBackup(snapshot, overwrite: false)
            lastBackupMetadata = CloudBackupMetadata(
                schemaVersion: snapshot.schemaVersion,
                createdAt: snapshot.createdAt,
                appVersion: snapshot.appVersion,
                collectionCount: snapshot.collectionCount,
                chapterCount: snapshot.chapterCount,
                historyCount: snapshot.historyCount)
            state = .available
            return .success
        } catch let error as CloudBackupError {
            state = .available
            switch error {
            case .newerBackupExists(let date):
                return .newerBackupExists(serverDate: date)
            case .noAccount:
                state = .noAccount
                return .failed(.noAccount)
            case .encodingFailed(let e):
                lastError = .encoding
                return .failed(.unknown(e.localizedDescription))
            default:
                let msg = String(describing: error)
                lastError = .network(msg)
                return .failed(.network(msg))
            }
        } catch {
            state = .available
            let msg = error.localizedDescription
            lastError = .unknown(msg)
            return .failed(.unknown(msg))
        }
    }

    func forceBackup() async -> BackupResult {
        guard state == .available else { return .failed(.noAccount) }
        state = .backingUp
        defer { if state == .backingUp { state = .available } }
        do {
            let snapshot = try store.makeBackupSnapshot()
            try await transport.saveBackup(snapshot, overwrite: true)
            lastBackupMetadata = CloudBackupMetadata(
                schemaVersion: snapshot.schemaVersion,
                createdAt: snapshot.createdAt,
                appVersion: snapshot.appVersion,
                collectionCount: snapshot.collectionCount,
                chapterCount: snapshot.chapterCount,
                historyCount: snapshot.historyCount)
            state = .available
            return .success
        } catch {
            state = .available
            let msg = error.localizedDescription
            lastError = .unknown(msg)
            return .failed(.unknown(msg))
        }
    }

    func restore() async -> RestoreResult {
        guard state == .available else { return .failed(.noAccount) }
        state = .restoring
        defer { if state == .restoring { state = .available } }
        do {
            let envelope = try await transport.fetchBackup()
            try store.restoreBackupSnapshot(envelope)
            state = .available
            return .success
        } catch let error as CloudBackupError {
            state = .available
            switch error {
            case .noBackupFound:
                return .noBackup
            case .noAccount:
                state = .noAccount
                return .failed(.noAccount)
            default:
                let msg = String(describing: error)
                lastError = .network(msg)
                return .failed(.network(msg))
            }
        } catch let error as BackupValidationError {
            state = .available
            lastError = .unknown(error.description)
            return .failed(.unknown(error.description))
        } catch {
            state = .available
            let msg = error.localizedDescription
            lastError = .unknown(msg)
            return .failed(.unknown(msg))
        }
    }
}
