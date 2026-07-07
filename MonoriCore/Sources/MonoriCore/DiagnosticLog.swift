import Foundation
import os

/// File-backed diagnostic log with a two-file ring buffer, exported manually
/// from Settings so TestFlight testers can hand over logs for non-crash
/// issues. Also forwards every entry to `os.Logger` (subsystem `dev.monori`)
/// so Console workflows and the smoke scripts' log predicate keep working.
///
/// COMPLIANCE.md: callers must never pass secrets, tokens, cookies, or post
/// content. URLs are limited to post/collection URLs already stored locally.
public final class DiagnosticLog: @unchecked Sendable {
    public static let shared = DiagnosticLog()

    private let queue = DispatchQueue(label: "dev.monori.diagnostic-log")
    private let directory: URL
    private let maxFileBytes: Int
    private let forwardToOSLog: Bool
    // Only touched on `queue` — DateFormatter is not thread-safe.
    private let formatter: DateFormatter

    var currentFileURL: URL { directory.appendingPathComponent("monori-diag.log") }
    var rotatedFileURL: URL { directory.appendingPathComponent("monori-diag.1.log") }

    public convenience init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        self.init(directory: base)
    }

    public init(directory: URL, maxFileBytes: Int = 256 * 1024,
                forwardToOSLog: Bool = true) {
        self.directory = directory
        self.maxFileBytes = maxFileBytes
        self.forwardToOSLog = forwardToOSLog
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter = f
    }

    public func log(category: String, _ message: String) {
        append(category: category, message: message, isError: false)
    }

    public func error(category: String, _ message: String) {
        append(category: category, message: message, isError: true)
    }

    /// Blocks until pending writes have landed. Test helper.
    public func flush() {
        queue.sync {}
    }

    private func append(category: String, message: String, isError: Bool) {
        if forwardToOSLog {
            let logger = Logger(subsystem: "dev.monori", category: category)
            if isError { logger.error("\(message, privacy: .public)") }
            else { logger.notice("\(message, privacy: .public)") }
        }
        let now = Date()
        queue.async { [self] in
            let stamp = formatter.string(from: now)
            let marker = isError ? " [ERROR]" : ""
            let line = "\(stamp) [\(category)]\(marker) \(message)\n"
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: currentFileURL.path) {
                    FileManager.default.createFile(atPath: currentFileURL.path,
                                                   contents: nil)
                }
                let handle = try FileHandle(forWritingTo: currentFileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                let size = try handle.offset()
                if size > UInt64(maxFileBytes) {
                    try? FileManager.default.removeItem(at: rotatedFileURL)
                    try FileManager.default.moveItem(at: currentFileURL,
                                                     to: rotatedFileURL)
                }
            } catch {
                // Diagnostics must never break the app — drop the line.
            }
        }
    }
}
