// MonoriCore/Tests/MonoriCoreTests/URLNormalizerAFFTests.swift
import XCTest
@testable import MonoriCore

final class URLNormalizerAFFTests: XCTestCase {

    // MARK: affStoryID

    func testExtractsStoryIDFromForewordWithSlug() {
        XCTAssertEqual(URLNormalizer.affStoryID("https://www.asianfanfics.com/story/view/1736914/n-a"), "1736914")
    }

    func testExtractsStoryIDFromForewordWithoutSlug() {
        XCTAssertEqual(URLNormalizer.affStoryID("https://www.asianfanfics.com/story/view/1738243"), "1738243")
    }

    func testExtractsStoryIDFromChapterURL() {
        XCTAssertEqual(URLNormalizer.affStoryID("https://www.asianfanfics.com/story/view/1736914/1/n-a"), "1736914")
    }

    func testExtractsStoryIDWithQueryParams() {
        XCTAssertEqual(URLNormalizer.affStoryID("https://www.asianfanfics.com/story/view/1736914/n-a?ref=home"), "1736914")
    }

    func testStoryIDNilForBareHost() {
        XCTAssertNil(URLNormalizer.affStoryID("https://www.asianfanfics.com"))
    }

    func testStoryIDNilForProfileURL() {
        XCTAssertNil(URLNormalizer.affStoryID("https://www.asianfanfics.com/profile/u/Jaylia"))
    }

    func testStoryIDNilForBrowsePage() {
        XCTAssertNil(URLNormalizer.affStoryID("https://www.asianfanfics.com/browse/all"))
    }

    func testStoryIDNilForNonAFF() {
        XCTAssertNil(URLNormalizer.affStoryID("https://archiveofourown.org/works/12345"))
    }

    func testStoryIDWithoutWWW() {
        XCTAssertEqual(URLNormalizer.affStoryID("https://asianfanfics.com/story/view/1736914/n-a"), "1736914")
    }

    // MARK: isAFFForewordURL

    func testForewordWithSlug() {
        XCTAssertTrue(URLNormalizer.isAFFForewordURL("https://www.asianfanfics.com/story/view/1736914/n-a"))
    }

    func testForewordWithoutSlug() {
        XCTAssertTrue(URLNormalizer.isAFFForewordURL("https://www.asianfanfics.com/story/view/1738243"))
    }

    func testChapterPageNotForeword() {
        XCTAssertFalse(URLNormalizer.isAFFForewordURL("https://www.asianfanfics.com/story/view/1736914/1/n-a"))
    }

    func testForewordWithNumericSlug() {
        // Purely numeric title slugs get a trailing hyphen: "2048" → "2048-"
        XCTAssertTrue(URLNormalizer.isAFFForewordURL("https://www.asianfanfics.com/story/view/1736914/2048-"))
    }

    func testChapterNumericFourthSegment() {
        // 4th segment is numeric → chapter page, not foreword
        XCTAssertFalse(URLNormalizer.isAFFForewordURL("https://www.asianfanfics.com/story/view/1736914/3"))
    }

    // MARK: isAFFStoryURL

    func testIsAFFStoryURL() {
        XCTAssertTrue(URLNormalizer.isAFFStoryURL("https://www.asianfanfics.com/story/view/1736914/n-a"))
    }

    func testIsAFFStoryURLNonAFF() {
        XCTAssertFalse(URLNormalizer.isAFFStoryURL("https://www.patreon.com/posts/12345"))
    }

    // MARK: canonicalAFFStoryURL

    func testCanonicalStripsSlug() {
        XCTAssertEqual(
            URLNormalizer.canonicalAFFStoryURL("https://www.asianfanfics.com/story/view/1736914/n-a"),
            "https://www.asianfanfics.com/story/view/1736914")
    }

    func testCanonicalStripsChapter() {
        XCTAssertEqual(
            URLNormalizer.canonicalAFFStoryURL("https://www.asianfanfics.com/story/view/1736914/1/n-a"),
            "https://www.asianfanfics.com/story/view/1736914")
    }

    func testCanonicalNilForNonAFF() {
        XCTAssertNil(URLNormalizer.canonicalAFFStoryURL("https://archiveofourown.org/works/12345"))
    }

    func testCanonicalAlreadyCanonical() {
        XCTAssertEqual(
            URLNormalizer.canonicalAFFStoryURL("https://www.asianfanfics.com/story/view/1738243"),
            "https://www.asianfanfics.com/story/view/1738243")
    }

    // MARK: canonicalAFFChapterURL

    func testCanonicalAFFChapterURL_stripsSlug() {
        let input = "https://www.asianfanfics.com/story/view/1695131/1/n-a"
        XCTAssertEqual(
            URLNormalizer.canonicalAFFChapterURL(input),
            "https://www.asianfanfics.com/story/view/1695131/1"
        )
    }

    func testCanonicalAFFChapterURL_alreadyCanonical() {
        let input = "https://www.asianfanfics.com/story/view/1695131/1"
        XCTAssertEqual(
            URLNormalizer.canonicalAFFChapterURL(input),
            "https://www.asianfanfics.com/story/view/1695131/1"
        )
    }

    func testCanonicalAFFChapterURL_forewordReturnsNil() {
        let input = "https://www.asianfanfics.com/story/view/1695131"
        XCTAssertNil(URLNormalizer.canonicalAFFChapterURL(input))
    }

    func testCanonicalAFFChapterURL_forewordWithSlugReturnsNil() {
        let input = "https://www.asianfanfics.com/story/view/1695131/some-title"
        XCTAssertNil(URLNormalizer.canonicalAFFChapterURL(input))
    }

    func testCanonicalAFFChapterURL_nonAFFReturnsNil() {
        let input = "https://www.patreon.com/posts/12345"
        XCTAssertNil(URLNormalizer.canonicalAFFChapterURL(input))
    }
}
