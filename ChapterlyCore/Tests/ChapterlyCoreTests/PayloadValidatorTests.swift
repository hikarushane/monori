import XCTest
import ChapterlyCore

final class PayloadValidatorTests: XCTestCase {
    private func validImporterBody() -> [String: Any] {
        [
            "title": "5 脣瓣",
            "url": "https://www.patreon.com/posts/5-123456",
            "visibleDateText": "June 1",
            "collectionName": "【更新中】焚心 The Burning Heart",
            "collectionURL": "https://www.patreon.com/collection/9999",
            "domOrder": 4
        ]
    }

    func testValidImporterPayload() throws {
        let p = try PayloadValidator.validateImporterChapter(validImporterBody()).get()
        XCTAssertEqual(p.title, "5 脣瓣")
        XCTAssertEqual(p.domOrder, 4)
        XCTAssertEqual(p.visibleDateText, "June 1")
    }

    func testNullDateBecomesNil() throws {
        var body = validImporterBody()
        body["visibleDateText"] = NSNull()
        let p = try PayloadValidator.validateImporterChapter(body).get()
        XCTAssertNil(p.visibleDateText)
    }

    func testForbiddenKeyRejectsWholeMessage() {
        for key in ["bodyText", "innerText", "innerHTML", "html", "content",
                    "article", "paragraphs", "images", "comments", "INNERHTML"] {
            var body = validImporterBody()
            body[key] = "anything"
            guard case .failure(let e) = PayloadValidator.validateImporterChapter(body) else {
                return XCTFail("accepted forbidden key \(key)")
            }
            XCTAssertEqual(e, .forbiddenKey(key.lowercased()))
        }
    }

    func testUnknownKeyRejects() {
        var body = validImporterBody()
        body["extra"] = 1
        guard case .failure(.unknownKey("extra")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted unknown key")
        }
    }

    func testMissingRequiredKeyRejects() {
        var body = validImporterBody()
        body.removeValue(forKey: "url")
        guard case .failure(.missingKey("url")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted missing url")
        }
    }

    func testOversizedStringRejects() {
        var body = validImporterBody()
        body["title"] = String(repeating: "x", count: 2000)
        guard case .failure(.tooLarge("title")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted oversized title")
        }
    }

    func testOversizedURLRejects() {
        var body = validImporterBody()
        body["url"] = "https://www.patreon.com/posts/" + String(repeating: "a", count: 3000)
        guard case .failure(.tooLarge("url")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted oversized url")
        }
    }

    func testNotADictionaryRejects() {
        guard case .failure(.notADictionary) = PayloadValidator.validateImporterChapter("a string") else {
            return XCTFail("accepted non-dictionary")
        }
    }

    func testValidProgressPayload() throws {
        let p = try PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/5-123456", "scrollProgress": 0.42]).get()
        XCTAssertEqual(p.scrollProgress, 0.42, accuracy: 0.001)
    }

    func testProgressClampedToUnitRange() throws {
        let p = try PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/x", "scrollProgress": 7.5]).get()
        XCTAssertEqual(p.scrollProgress, 1.0)
    }

    func testProgressRejectsForbiddenExtraField() {
        guard case .failure(.forbiddenKey("html")) = PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/x", "scrollProgress": 0.5, "html": "<p>"])
        else { return XCTFail("accepted forbidden field") }
    }

    func testProgressRejectsUnknownExtraField() {
        guard case .failure(.unknownKey("extra")) = PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/x", "scrollProgress": 0.5, "extra": 1])
        else { return XCTFail("accepted unknown field") }
    }

    func testValidCollectionLinkPayload() throws {
        let p = try PayloadValidator.validateCollectionLink(
            ["collectionName": "焚心", "collectionURL": "https://www.patreon.com/collection/9999"]).get()
        XCTAssertEqual(p.collectionName, "焚心")
    }
}
