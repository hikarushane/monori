import XCTest
import ChapterlyCore

final class URLNormalizerTests: XCTestCase {
    func testNormalizesHostSchemeAndTrailingSlash() {
        let url = URL(string: "http://patreon.com/posts/some-post-123456/")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString,
                       "https://www.patreon.com/posts/some-post-123456")
    }

    func testStripsTrackingParamsAndFragment() {
        let url = URL(string: "https://www.patreon.com/posts/abc-987?utm_source=feed&utm_medium=x&fan_landing=true&mc_cid=1#comments")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString,
                       "https://www.patreon.com/posts/abc-987")
    }

    func testKeepsNonTrackingQuery() {
        let url = URL(string: "https://www.patreon.com/collection/12345?view=expanded")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString,
                       "https://www.patreon.com/collection/12345?view=expanded")
    }

    func testNonPatreonURLReturnsNil() {
        XCTAssertNil(URLNormalizer.normalize(URL(string: "https://example.com/posts/1")!))
    }

    func testRootPathKeepsSlash() {
        let url = URL(string: "https://patreon.com/")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString, "https://www.patreon.com/")
    }

    func testStringConvenience() {
        XCTAssertEqual(URLNormalizer.normalize("https://patreon.com/posts/x-1?utm_campaign=z")?.absoluteString,
                       "https://www.patreon.com/posts/x-1")
        XCTAssertNil(URLNormalizer.normalize("not a url ::"))
    }

    func testIsPatreonHomeMatchesHomeAndRoot() {
        XCTAssertTrue(URLNormalizer.isPatreonHome(URL(string: "https://www.patreon.com/home")!))
        XCTAssertTrue(URLNormalizer.isPatreonHome(URL(string: "https://patreon.com/home/")!))
        XCTAssertTrue(URLNormalizer.isPatreonHome(URL(string: "https://www.patreon.com/")!))
        XCTAssertTrue(URLNormalizer.isPatreonHome(URL(string: "https://www.patreon.com/home?utm_source=x")!))
    }

    func testIsPatreonHomeRejectsOtherPages() {
        XCTAssertFalse(URLNormalizer.isPatreonHome(URL(string: "https://www.patreon.com/posts/abc-123")!))
        XCTAssertFalse(URLNormalizer.isPatreonHome(URL(string: "https://www.patreon.com/collection/2040508")!))
        XCTAssertFalse(URLNormalizer.isPatreonHome(URL(string: "https://www.patreon.com/c/somecreator/home")!))
        XCTAssertFalse(URLNormalizer.isPatreonHome(URL(string: "https://example.com/home")!))
    }

    func testPatreonPostIDExtractsNumericAndSluggedPostURLs() {
        XCTAssertEqual(URLNormalizer.patreonPostID("https://www.patreon.com/posts/160628832"),
                       "160628832")
        XCTAssertEqual(URLNormalizer.patreonPostID("https://www.patreon.com/posts/chapter-title-160628832?utm_source=x"),
                       "160628832")
        XCTAssertEqual(URLNormalizer.patreonPostID("https://www.patreon.com/cw/ocean068/posts/chapter-title-160628832"),
                       "160628832")
        XCTAssertNil(URLNormalizer.patreonPostID("https://www.patreon.com/collection/2123904"))
    }
}
