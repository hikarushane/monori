import XCTest
@testable import MonoriCore

final class LocalFileIdentityTests: XCTestCase {
    func testSourceURLStringPercentEncodesFileName() {
        XCTAssertEqual(LocalFileIdentity.sourceURLString(fileName: "我的 小說.txt"),
                       "monori-local://file/%E6%88%91%E7%9A%84%20%E5%B0%8F%E8%AA%AA.txt")
    }

    func testChapterURLStringAppendsOrderIndex() {
        let src = LocalFileIdentity.sourceURLString(fileName: "a.epub")
        XCTAssertEqual(LocalFileIdentity.chapterURLString(sourceURLString: src, orderIndex: 3),
                       "monori-local://file/a.epub#3")
    }

    func testTitleDropsExtensionOnly() {
        XCTAssertEqual(LocalFileIdentity.title(fromFileName: "Undone.by.Time.pdf"), "Undone.by.Time")
        XCTAssertEqual(LocalFileIdentity.title(fromFileName: "noext"), "noext")
    }

    func testLocalFileIsRegisteredButNotBrowsableOrAutoChecked() {
        XCTAssertTrue(SourceRegistry.all.contains { $0.kind == .localFile })
        XCTAssertFalse(SourceRegistry.browsable.contains { $0.kind == .localFile })
        XCTAssertEqual(SourceRegistry.browsable.count, SourceRegistry.all.count - 1)
        XCTAssertEqual(SourceRegistry.provider(for: .localFile).displayName, "本機檔案")
        XCTAssertFalse(SourceKind.localFile.supportsAutoCheck)
    }

    func testErrorMessagesAreNonEmpty() {
        let all: [LocalFileImportError] = [.unsupportedType, .fileTooLarge, .unreadableFile,
            .undecodableText, .notAnEPUB, .drmProtected, .epubWithoutSpine,
            .unreadablePDF, .encryptedPDF, .pdfWithoutText, .noChapters]
        for e in all { XCTAssertFalse(e.message.isEmpty, "\(e)") }
        XCTAssertEqual(LocalFileIdentity.maxFileSize, 50 * 1024 * 1024)
    }
}
