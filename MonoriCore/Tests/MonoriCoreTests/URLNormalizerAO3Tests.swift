import XCTest
@testable import MonoriCore

final class URLNormalizerAO3Tests: XCTestCase {

    // MARK: ao3WorkID

    func testExtractsWorkID() {
        XCTAssertEqual(URLNormalizer.ao3WorkID("https://archiveofourown.org/works/12345"), "12345")
        XCTAssertEqual(URLNormalizer.ao3WorkID("https://archiveofourown.org/works/12345/chapters/67890"), "12345")
        XCTAssertEqual(URLNormalizer.ao3WorkID("https://archiveofourown.org/works/12345/navigate"), "12345")
        XCTAssertEqual(URLNormalizer.ao3WorkID("https://archiveofourown.org/works/12345?view_adult=true"), "12345")
    }

    func testRejectsNonWorkURLs() {
        XCTAssertNil(URLNormalizer.ao3WorkID("https://archiveofourown.org/users/someone"))
        XCTAssertNil(URLNormalizer.ao3WorkID("https://archiveofourown.org/series/999"))
        XCTAssertNil(URLNormalizer.ao3WorkID("https://archiveofourown.org/tags/Fantasy"))
        XCTAssertNil(URLNormalizer.ao3WorkID("https://www.patreon.com/posts/12345"))
        XCTAssertNil(URLNormalizer.ao3WorkID("https://archiveofourown.org/works/abc"))
    }

    // MARK: ao3ChapterID

    func testExtractsChapterID() {
        XCTAssertEqual(URLNormalizer.ao3ChapterID("https://archiveofourown.org/works/12345/chapters/67890"), "67890")
    }

    func testChapterIDNilForWorkWithoutChapter() {
        XCTAssertNil(URLNormalizer.ao3ChapterID("https://archiveofourown.org/works/12345"))
        XCTAssertNil(URLNormalizer.ao3ChapterID("https://archiveofourown.org/works/12345/navigate"))
    }

    // MARK: isAO3WorkURL

    func testIsAO3WorkURL() {
        XCTAssertTrue(URLNormalizer.isAO3WorkURL("https://archiveofourown.org/works/12345"))
        XCTAssertTrue(URLNormalizer.isAO3WorkURL("https://archiveofourown.org/works/12345/chapters/67890"))
        XCTAssertTrue(URLNormalizer.isAO3WorkURL("https://archiveofourown.org/works/12345?view_adult=true"))
        XCTAssertFalse(URLNormalizer.isAO3WorkURL("https://archiveofourown.org/series/999"))
        XCTAssertFalse(URLNormalizer.isAO3WorkURL("https://www.patreon.com/posts/12345"))
    }

    // MARK: isAO3SeriesURL

    func testIsAO3SeriesURL() {
        XCTAssertTrue(URLNormalizer.isAO3SeriesURL("https://archiveofourown.org/series/999"))
        XCTAssertFalse(URLNormalizer.isAO3SeriesURL("https://archiveofourown.org/works/12345"))
        XCTAssertFalse(URLNormalizer.isAO3SeriesURL("https://archiveofourown.org/users/someone"))
    }

    // MARK: canonical URLs

    func testCanonicalWorkURL() {
        XCTAssertEqual(
            URLNormalizer.canonicalAO3WorkURL("https://archiveofourown.org/works/12345/chapters/67890"),
            "https://archiveofourown.org/works/12345")
        XCTAssertEqual(
            URLNormalizer.canonicalAO3WorkURL("https://archiveofourown.org/works/12345?view_adult=true"),
            "https://archiveofourown.org/works/12345")
        XCTAssertNil(URLNormalizer.canonicalAO3WorkURL("https://archiveofourown.org/series/999"))
    }

    func testCanonicalChapterURL() {
        XCTAssertEqual(
            URLNormalizer.canonicalAO3ChapterURL("https://archiveofourown.org/works/12345/chapters/67890"),
            "https://archiveofourown.org/works/12345/chapters/67890")
        XCTAssertNil(URLNormalizer.canonicalAO3ChapterURL("https://archiveofourown.org/works/12345"))
    }
}
