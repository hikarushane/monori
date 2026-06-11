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

    func testContaminatedStoredTextUsesFirstLineAsTitleAndSeparatesPreview() {
        let stored = """
        第十六章 陽光普照
        這是第二行內文。
        這是第三行內文。
        """
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: stored,
            urlString: "https://www.patreon.com/posts/real-chapter-title-160628832")
        XCTAssertEqual(presentation.title, "第十六章 陽光普照")
        XCTAssertEqual(presentation.preview, "這是第二行內文。\n這是第三行內文。")
    }

    func testSingleLineLongTextIsFlaggedAsContaminated() {
        let longLine = String(repeating: "文", count: 120)
        XCTAssertTrue(ChapterTextFormatter.isProbablyContaminatedTitle(longLine))
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: longLine,
            urlString: "https://www.patreon.com/posts/some-slug-160628832")
        XCTAssertEqual(presentation.title, "some slug")
        XCTAssertNotNil(presentation.preview)
    }

    func testTwoLineTextIsFlaggedAsContaminated() {
        XCTAssertTrue(ChapterTextFormatter.isProbablyContaminatedTitle("標題\n摘要"))
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: "標題\n摘要",
            urlString: "https://www.patreon.com/posts/160628832")
        XCTAssertEqual(presentation.title, "標題")
        XCTAssertEqual(presentation.preview, "摘要")
    }

    func testBodyTextWithChinesePeriodIsFlagged() {
        let bodyText = "興奮得一整晚沒睡好的 Orm，大清早就到了 Ling 家樓下眼巴巴地等著了。"
        XCTAssertTrue(ChapterTextFormatter.isProbablyContaminatedTitle(bodyText))
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: bodyText,
            urlString: "https://www.patreon.com/posts/some-slug-160628832")
        XCTAssertEqual(presentation.title, "some slug")
        XCTAssertNotNil(presentation.preview)
    }

    func testBodyTextWithoutURLSlugFallsBackToGeneric() {
        let bodyText = "週末清晨，陽光才剛在地平線上露了個頭。"
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: bodyText,
            urlString: "https://www.patreon.com/posts/160628832")
        XCTAssertEqual(presentation.title, "Patreon post")
        XCTAssertNotNil(presentation.preview)
    }

    func testCleanTitleWithPunctuationInPreviewNotFlagged() {
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: "第十六章 陽光普照",
            urlString: "https://www.patreon.com/posts/160628832")
        XCTAssertEqual(presentation.title, "第十六章 陽光普照")
        XCTAssertNil(presentation.preview)
    }

    func testTitleWithQuestionMarkNotFlagged() {
        let title = "《少爺的剋星》 第二十六集：我想妳了，那妳呢？"
        XCTAssertFalse(ChapterTextFormatter.isProbablyContaminatedTitle(title))
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: title,
            urlString: "https://www.patreon.com/posts/160628832")
        XCTAssertEqual(presentation.title, title)
        XCTAssertNil(presentation.preview)
    }

    func testContaminatedDetectionDoesNotFlagManualRename() {
        XCTAssertFalse(ChapterTextFormatter.isProbablyContaminatedTitle("My renamed title"))
        XCTAssertFalse(ChapterTextFormatter.isProbablyContaminatedTitle("第十六章 陽光普照"))
        XCTAssertFalse(ChapterTextFormatter.isProbablyContaminatedTitle("結局：她終於笑了！"))
        XCTAssertTrue(ChapterTextFormatter.isProbablyContaminatedTitle("這是一段內文。"))
        XCTAssertTrue(ChapterTextFormatter.isProbablyContaminatedTitle("""
        第一行內文。
        第二行內文。
        第三行內文。
        """))
    }

    func testPreviewTruncatedToMaxLength() {
        let title = "標題"
        let longBody = String(repeating: "內文測試段落", count: 50)
        let stored = title + "\n" + longBody
        let presentation = ChapterTextFormatter.presentation(
            storedTitle: stored,
            urlString: "https://www.patreon.com/posts/160628832")
        XCTAssertEqual(presentation.title, "標題")
        XCTAssertNotNil(presentation.preview)
        XCTAssertLessThanOrEqual(presentation.preview!.count, 150)
    }
}
