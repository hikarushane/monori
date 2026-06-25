import XCTest
@testable import MonoriCore

final class URLNormalizerVocusTests: XCTestCase {

    // MARK: isVocusRoomURL

    func testRoomURLRecognized() {
        XCTAssertTrue(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass"))
    }

    func testRoomURLWithCategoryRecognized() {
        XCTAssertTrue(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass/%E6%96%87%E7%AB%A0"))
    }

    func testSalonHomeNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a"))
    }

    func testSalonAboutNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a/about"))
    }

    func testArticleURLNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    func testNonVocusURLNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://www.patreon.com/collection/12345"))
    }

    func testRoomURLWithShortSalonIDRejected() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/abc/room/bass"))
    }

    // MARK: vocusRoomSlug

    func testExtractsRoomSlug() {
        XCTAssertEqual(URLNormalizer.vocusRoomSlug("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass"), "bass")
    }

    func testRoomSlugWithCategory() {
        XCTAssertEqual(URLNormalizer.vocusRoomSlug("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass/cat"), "bass")
    }

    func testRoomSlugNilForNonRoom() {
        XCTAssertNil(URLNormalizer.vocusRoomSlug("https://vocus.cc/salon/65a4a22bfd89780001e7867a"))
    }

    // MARK: vocusSalonID

    func testExtractsSalonIDFromRoom() {
        XCTAssertEqual(URLNormalizer.vocusSalonID("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass"),
                       "65a4a22bfd89780001e7867a")
    }

    func testExtractsSalonIDFromSalonHome() {
        XCTAssertEqual(URLNormalizer.vocusSalonID("https://vocus.cc/salon/65a4a22bfd89780001e7867a"),
                       "65a4a22bfd89780001e7867a")
    }

    func testSalonIDNilForArticle() {
        XCTAssertNil(URLNormalizer.vocusSalonID("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    // MARK: isVocusArticleURL

    func testArticleURLRecognized() {
        XCTAssertTrue(URLNormalizer.isVocusArticleURL("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    func testArticleURLWithShortIDRejected() {
        XCTAssertFalse(URLNormalizer.isVocusArticleURL("https://vocus.cc/article/abc123"))
    }

    func testRoomURLNotArticle() {
        XCTAssertFalse(URLNormalizer.isVocusArticleURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass"))
    }

    // MARK: vocusArticleID

    func testExtractsArticleID() {
        XCTAssertEqual(URLNormalizer.vocusArticleID("https://vocus.cc/article/67ca7699fd897800017f312c"),
                       "67ca7699fd897800017f312c")
    }

    func testArticleIDNilForNonArticle() {
        XCTAssertNil(URLNormalizer.vocusArticleID("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass"))
    }

    // MARK: canonicalVocusRoomURL

    func testCanonicalRoomURL() {
        XCTAssertEqual(
            URLNormalizer.canonicalVocusRoomURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass/%E6%96%87%E7%AB%A0"),
            "https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass")
    }

    func testCanonicalRoomURLAlreadyCanonical() {
        XCTAssertEqual(
            URLNormalizer.canonicalVocusRoomURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass"),
            "https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass")
    }

    func testCanonicalRoomURLNilForNonRoom() {
        XCTAssertNil(URLNormalizer.canonicalVocusRoomURL("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }
}
