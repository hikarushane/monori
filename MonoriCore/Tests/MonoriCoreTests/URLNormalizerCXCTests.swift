import XCTest
@testable import MonoriCore

final class URLNormalizerCXCTests: XCTestCase {

    // MARK: isCXCHost

    func testIsCXCHost() {
        XCTAssertTrue(URLNormalizer.isCXCHost(URL(string: "https://cxc.today")!))
        XCTAssertTrue(URLNormalizer.isCXCHost(URL(string: "https://bl.cxc.today")!))
        XCTAssertTrue(URLNormalizer.isCXCHost(URL(string: "https://bg.cxc.today/zh/@foo/work/123")!))
        XCTAssertFalse(URLNormalizer.isCXCHost(URL(string: "https://example.com")!))
        XCTAssertFalse(URLNormalizer.isCXCHost(URL(string: "https://notcxc.today")!))
    }

    func testIsCXCHostSubdomainVariants() {
        XCTAssertTrue(URLNormalizer.isCXCHost(URL(string: "https://gl.cxc.today")!))
    }

    func testIsCXCHostCaseInsensitive() {
        XCTAssertTrue(URLNormalizer.isCXCHost(URL(string: "https://CXC.TODAY")!))
        XCTAssertTrue(URLNormalizer.isCXCHost(URL(string: "https://BL.CXC.TODAY")!))
    }

    // MARK: cxcWorkID

    func testCXCWorkID() {
        XCTAssertEqual(
            URLNormalizer.cxcWorkID(URL(string: "https://cxc.today/zh/@nanami777/work/38982")!),
            "38982")
        XCTAssertEqual(
            URLNormalizer.cxcWorkID(URL(string: "https://bl.cxc.today/en/@foo/work/12345")!),
            "12345")
        XCTAssertNil(URLNormalizer.cxcWorkID(URL(string: "https://cxc.today/zh/@foo")!))
    }

    func testCXCWorkIDWithChapterSuffix() {
        XCTAssertEqual(
            URLNormalizer.cxcWorkID(URL(string: "https://cxc.today/zh/@foo/work/123/chapter/1")!),
            "123")
    }

    func testCXCWorkIDNilForNonNumericID() {
        XCTAssertNil(URLNormalizer.cxcWorkID(URL(string: "https://cxc.today/zh/@foo/work/abc")!))
    }

    func testCXCWorkIDNilForNonCXCHost() {
        XCTAssertNil(URLNormalizer.cxcWorkID(URL(string: "https://example.com/zh/@foo/work/123")!))
    }

    func testCXCWorkIDWithoutLanguagePrefix() {
        XCTAssertEqual(
            URLNormalizer.cxcWorkID(URL(string: "https://cxc.today/@foo/work/123")!),
            "123")
    }

    // MARK: cxcUsername

    func testCXCUsername() {
        XCTAssertEqual(
            URLNormalizer.cxcUsername(URL(string: "https://cxc.today/zh/@nanami777/work/38982")!),
            "nanami777")
        XCTAssertNil(URLNormalizer.cxcUsername(URL(string: "https://cxc.today/zh/explore")!))
    }

    func testCXCUsernameCreatorStoreURL() {
        XCTAssertEqual(
            URLNormalizer.cxcUsername(URL(string: "https://cxc.today/zh/@nanami777")!),
            "nanami777")
    }

    func testCXCUsernameNilForNonCXCHost() {
        XCTAssertNil(URLNormalizer.cxcUsername(URL(string: "https://example.com/zh/@foo")!))
    }

    // MARK: isCXCWorkURL

    func testIsCXCWorkURL() {
        XCTAssertTrue(URLNormalizer.isCXCWorkURL(URL(string: "https://cxc.today/zh/@foo/work/123")!))
        XCTAssertTrue(URLNormalizer.isCXCWorkURL(URL(string: "https://bl.cxc.today/jp/@bar/work/456")!))
        XCTAssertFalse(URLNormalizer.isCXCWorkURL(URL(string: "https://cxc.today/zh/@foo")!))
        XCTAssertFalse(URLNormalizer.isCXCWorkURL(URL(string: "https://cxc.today/zh/explore")!))
    }

    func testIsCXCWorkURLTrueForChapterURL() {
        XCTAssertTrue(URLNormalizer.isCXCWorkURL(URL(string: "https://cxc.today/zh/@foo/work/123/chapter/1")!))
    }

    func testIsCXCWorkURLFalseForNonCXCHost() {
        XCTAssertFalse(URLNormalizer.isCXCWorkURL(URL(string: "https://example.com/zh/@foo/work/123")!))
    }

    // MARK: canonicalCXCWorkURL

    func testCanonicalCXCWorkURL() {
        let canonical = URLNormalizer.canonicalCXCWorkURL(
            URL(string: "https://bl.cxc.today/en/@nanami777/work/38982")!)
        XCTAssertEqual(canonical?.absoluteString, "https://cxc.today/@nanami777/work/38982")
    }

    func testCanonicalCXCWorkURLAlreadyCanonical() {
        let canonical = URLNormalizer.canonicalCXCWorkURL(
            URL(string: "https://cxc.today/zh/@nanami777/work/38982")!)
        XCTAssertEqual(canonical?.absoluteString, "https://cxc.today/@nanami777/work/38982")
    }

    func testCanonicalCXCWorkURLStripsChapterSuffix() {
        let canonical = URLNormalizer.canonicalCXCWorkURL(
            URL(string: "https://gl.cxc.today/ko/@foo/work/456/chapter/3")!)
        XCTAssertEqual(canonical?.absoluteString, "https://cxc.today/@foo/work/456")
    }

    func testCanonicalCXCWorkURLForBookType() {
        let canonical = URLNormalizer.canonicalCXCWorkURL(
            URL(string: "https://bl.cxc.today/zh/@bubbledingding/book/55150")!)
        XCTAssertEqual(canonical?.absoluteString, "https://cxc.today/@bubbledingding/book/55150")
    }

    func testCXCWorkIDForBookURL() {
        let id = URLNormalizer.cxcWorkID(
            URL(string: "https://cxc.today/zh/@foo/book/789")!)
        XCTAssertEqual(id, "789")
    }

    func testIsCXCWorkURLForBookURL() {
        XCTAssertTrue(URLNormalizer.isCXCWorkURL(
            URL(string: "https://cxc.today/@user/book/123")!))
    }

    func testCanonicalCXCReaderURL() {
        let canonical = URLNormalizer.canonicalCXCReaderURL(
            "https://cxc.today/zh/@laterne/work/24551/reader/160694")
        XCTAssertEqual(canonical, "https://cxc.today/@laterne/work/24551/reader/160694")
    }

    func testCanonicalCXCReaderURLForBookType() {
        let canonical = URLNormalizer.canonicalCXCReaderURL(
            "https://bl.cxc.today/en/@user/book/100/reader/200")
        XCTAssertEqual(canonical, "https://cxc.today/@user/book/100/reader/200")
    }

    func testCanonicalCXCReaderURLStripsLangPrefix() {
        let withLang = URLNormalizer.canonicalCXCReaderURL(
            "https://cxc.today/zh/@foo/work/1/reader/2")
        let withoutLang = URLNormalizer.canonicalCXCReaderURL(
            "https://cxc.today/@foo/work/1/reader/2")
        XCTAssertEqual(withLang, withoutLang)
    }

    func testCanonicalCXCWorkURLNilForCreatorStoreOnly() {
        XCTAssertNil(URLNormalizer.canonicalCXCWorkURL(URL(string: "https://cxc.today/zh/@foo")!))
    }

    func testCanonicalCXCWorkURLNilForNonCXCHost() {
        XCTAssertNil(URLNormalizer.canonicalCXCWorkURL(URL(string: "https://example.com/zh/@foo/work/123")!))
    }
}
