import Foundation
import XCTest
@testable import MonoriCore

final class DiagnosticLogTests: XCTestCase {
    private var dir: URL!
    private var log: DiagnosticLog!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("diaglog-\(UUID().uuidString)", isDirectory: true)
        // Tiny maxFileBytes so rotation is testable.
        log = DiagnosticLog(directory: dir, maxFileBytes: 200, forwardToOSLog: false)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func currentText() throws -> String {
        try String(contentsOf: dir.appendingPathComponent("monori-diag.log"),
                   encoding: .utf8)
    }

    private func rotatedText() throws -> String {
        try String(contentsOf: dir.appendingPathComponent("monori-diag.1.log"),
                   encoding: .utf8)
    }

    func testLogWritesFormattedLine() throws {
        log.log(category: "import", "collection detected")
        log.flush()
        let line = try currentText().trimmingCharacters(in: .newlines)
        // e.g. 2026-07-07T14:03:21+0800 [import] collection detected
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4} \[import\] collection detected$"#
        XCTAssertNotNil(line.range(of: pattern, options: .regularExpression),
                        "unexpected line: \(line)")
    }

    func testErrorLineCarriesErrorMarker() throws {
        log.error(category: "reader", "css failed")
        log.flush()
        XCTAssertTrue(try currentText().contains("[reader] [ERROR] css failed"))
    }

    func testRotationMovesCurrentToDotOneAndStartsFresh() throws {
        // Each line is ~76 bytes (24-byte stamp + category + 46-char message).
        // maxFileBytes=200 → rotation triggers after the 3rd line.
        let pad = String(repeating: "a", count: 40)
        log.log(category: "t", "first-\(pad)")
        log.log(category: "t", "second-\(pad)")
        log.log(category: "t", "third-\(pad)")   // pushes past 200 → rotate
        log.log(category: "t", "fourth-\(pad)")  // lands in fresh current
        log.flush()

        let rotated = try rotatedText()
        XCTAssertTrue(rotated.contains("first-"))
        XCTAssertTrue(rotated.contains("second-"))
        XCTAssertTrue(rotated.contains("third-"))
        let current = try currentText()
        XCTAssertTrue(current.contains("fourth-"))
        XCTAssertFalse(current.contains("first-"))
    }

    func testSecondRotationOverwritesOldDotOne() throws {
        let pad = String(repeating: "a", count: 40)
        for i in 0..<3 { log.log(category: "t", "gen1-\(i)-\(pad)") }  // rotation 1
        for i in 0..<3 { log.log(category: "t", "gen2-\(i)-\(pad)") }  // rotation 2
        log.flush()
        let rotated = try rotatedText()
        XCTAssertTrue(rotated.contains("gen2-0-"))
        XCTAssertFalse(rotated.contains("gen1-0-"), ".1 must be overwritten, not appended")
    }

    func testConcurrentWritesProduceWholeLines() throws {
        // Separate instance with a large cap so rotation never drops lines here.
        let bigDir = dir.appendingPathComponent("big", isDirectory: true)
        let big = DiagnosticLog(directory: bigDir, maxFileBytes: 1_000_000,
                                forwardToOSLog: false)
        DispatchQueue.concurrentPerform(iterations: 50) { i in
            big.log(category: "t", "line-\(i)")
        }
        big.flush()
        let lines = try String(
            contentsOf: bigDir.appendingPathComponent("monori-diag.log"),
            encoding: .utf8
        ).split(separator: "\n")
        XCTAssertEqual(lines.count, 50)
        XCTAssertTrue(lines.allSatisfy { $0.contains(" [t] line-") })
    }
}
