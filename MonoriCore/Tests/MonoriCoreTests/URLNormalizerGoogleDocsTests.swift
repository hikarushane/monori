import XCTest
@testable import MonoriCore

final class URLNormalizerGoogleDocsTests: XCTestCase {
    func testExtractsDocID() {
        XCTAssertEqual(URLNormalizer.googleDocID("https://docs.google.com/document/d/ABC123/edit?tab=t.0"), "ABC123")
        XCTAssertEqual(URLNormalizer.googleDocID("https://docs.google.com/document/u/0/d/ABC123/edit"), "ABC123")
        XCTAssertEqual(URLNormalizer.googleDocID("https://docs.google.com/document/d/ABC123/mobilebasic"), "ABC123")
        XCTAssertEqual(URLNormalizer.googleDocID("https://docs.google.com/document/d/ABC123"), "ABC123")
    }

    func testRejectsNonDocs() {
        XCTAssertNil(URLNormalizer.googleDocID("https://www.patreon.com/posts/1"))
        XCTAssertNil(URLNormalizer.googleDocID("https://drive.google.com/drive/folders/xyz"))
        XCTAssertNil(URLNormalizer.googleDocID("https://docs.google.com/spreadsheets/d/XYZ/edit"))
    }

    func testCanonicalStripsEditAndTab() {
        XCTAssertEqual(URLNormalizer.canonicalGoogleDocURL("https://docs.google.com/document/d/ABC123/edit?tab=t.0#h.x"),
                       "https://docs.google.com/document/d/ABC123")
    }

    func testIsGoogleDocURL() {
        XCTAssertTrue(URLNormalizer.isGoogleDocURL("https://docs.google.com/document/d/ABC123/edit"))
        // account-prefixed multi-login URL - the exact form that previously hid the import button
        XCTAssertTrue(URLNormalizer.isGoogleDocURL("https://docs.google.com/document/u/0/d/ABC123/edit"))
        XCTAssertTrue(URLNormalizer.isGoogleDocURL("https://docs.google.com/document/d/ABC123/mobilebasic"))
    }

    func testIsGoogleDocURLRejectsNonDocs() {
        XCTAssertFalse(URLNormalizer.isGoogleDocURL("https://drive.google.com/drive/folders/xyz"))
        XCTAssertFalse(URLNormalizer.isGoogleDocURL("https://drive.google.com/file/d/ABC/view"))
        XCTAssertFalse(URLNormalizer.isGoogleDocURL("https://www.patreon.com/posts/1"))
        // Non-document Google editors must NOT show the doc import button.
        XCTAssertFalse(URLNormalizer.isGoogleDocURL("https://docs.google.com/spreadsheets/d/XYZ/edit"))
        XCTAssertFalse(URLNormalizer.isGoogleDocURL("https://docs.google.com/presentation/d/XYZ/edit"))
        XCTAssertFalse(URLNormalizer.isGoogleDocURL("https://docs.google.com/forms/d/XYZ/edit"))
    }
}
