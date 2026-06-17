import XCTest
@testable import ChapterlyCore

final class URLNormalizerGoogleDocsTests: XCTestCase {
    func testExtractsDocID() {
        XCTAssertEqual(URLNormalizer.googleDocID("https://docs.google.com/document/d/ABC123/edit?tab=t.0"), "ABC123")
        XCTAssertEqual(URLNormalizer.googleDocID("https://docs.google.com/document/d/ABC123/mobilebasic"), "ABC123")
        XCTAssertEqual(URLNormalizer.googleDocID("https://docs.google.com/document/d/ABC123"), "ABC123")
    }

    func testRejectsNonDocs() {
        XCTAssertNil(URLNormalizer.googleDocID("https://www.patreon.com/posts/1"))
        XCTAssertNil(URLNormalizer.googleDocID("https://drive.google.com/drive/folders/xyz"))
    }

    func testCanonicalStripsEditAndTab() {
        XCTAssertEqual(URLNormalizer.canonicalGoogleDocURL("https://docs.google.com/document/d/ABC123/edit?tab=t.0#h.x"),
                       "https://docs.google.com/document/d/ABC123")
    }
}
