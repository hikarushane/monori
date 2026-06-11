import XCTest
import ChapterlyCore

final class ChapterTextFormatterTests: XCTestCase {
    func testShortTitleDisplaysAsTitleOnly() {
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: "真正的文章標題",
            urlString: "https://www.patreon.com/posts/160628832")
        XCTAssertEqual(presentation.title, "真正的文章標題")
        XCTAssertNil(presentation.preview)
    }

    func testContaminatedStoredTextUsesURLSlugAsTitleAndKeepsPreviewCollapsed() {
        let stored = """
        FAKE_BODY_TEXT_MUST_NEVER_LEAK 這是第一行內文。
        這是第二行內文。
        這是第三行內文。
        """
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: stored,
            urlString: "https://www.patreon.com/posts/real-chapter-title-160628832")
        XCTAssertEqual(presentation.title, "real chapter title")
        XCTAssertEqual(presentation.preview, "FAKE_BODY_TEXT_MUST_NEVER_LEAK 這是第一行內文。\n這是第二行內文。\n這是第三行內文。")
    }

    func testContaminatedDetectionDoesNotFlagManualRename() {
        XCTAssertFalse(ChapterTextFormatter.isProbablyContaminatedTitle("My renamed title"))
        XCTAssertTrue(ChapterTextFormatter.isProbablyContaminatedTitle("""
        第一行內文。
        第二行內文。
        第三行內文。
        """))
    }
}
