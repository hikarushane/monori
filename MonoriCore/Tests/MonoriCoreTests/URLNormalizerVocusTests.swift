import XCTest
@testable import MonoriCore

final class URLNormalizerVocusTests: XCTestCase {

    // MARK: isVocusRoomURL

    func testRoomURLWithSlugSalonID() {
        XCTAssertTrue(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853"))
    }

    func testRoomURLWithHexSalonID() {
        XCTAssertTrue(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/65a4a22bfd89780001e7867a/room/bass"))
    }

    func testRoomURLWithCategoryRecognized() {
        XCTAssertTrue(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853/%E6%96%87%E7%AB%A0"))
    }

    func testSalonHomeNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/Aliens"))
    }

    func testSalonAboutNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://vocus.cc/salon/Aliens/about"))
    }

    func testArticleURLNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    func testNonVocusURLNotRoom() {
        XCTAssertFalse(URLNormalizer.isVocusRoomURL("https://www.patreon.com/collection/12345"))
    }

    // MARK: vocusRoomSlug

    func testExtractsRoomSlug() {
        XCTAssertEqual(URLNormalizer.vocusRoomSlug("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853"),
                       "69c87373694f1e8d97d07853")
    }

    func testRoomSlugWithCategory() {
        XCTAssertEqual(URLNormalizer.vocusRoomSlug("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853/cat"),
                       "69c87373694f1e8d97d07853")
    }

    func testRoomSlugNilForNonRoom() {
        XCTAssertNil(URLNormalizer.vocusRoomSlug("https://vocus.cc/salon/Aliens"))
    }

    // MARK: vocusSalonID

    func testExtractsSlugSalonID() {
        XCTAssertEqual(URLNormalizer.vocusSalonID("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853"),
                       "Aliens")
    }

    func testExtractsHexSalonID() {
        XCTAssertEqual(URLNormalizer.vocusSalonID("https://vocus.cc/salon/65a4a22bfd89780001e7867a"),
                       "65a4a22bfd89780001e7867a")
    }

    func testSalonIDNilForArticle() {
        XCTAssertNil(URLNormalizer.vocusSalonID("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    func testSalonIDNilForNonVocus() {
        XCTAssertNil(URLNormalizer.vocusSalonID("https://www.patreon.com/salon/Aliens"))
    }

    // MARK: isVocusArticleURL

    func testArticleURLRecognized() {
        XCTAssertTrue(URLNormalizer.isVocusArticleURL("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    func testArticleURLWithShortIDRejected() {
        XCTAssertFalse(URLNormalizer.isVocusArticleURL("https://vocus.cc/article/abc123"))
    }

    func testRoomURLNotArticle() {
        XCTAssertFalse(URLNormalizer.isVocusArticleURL("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853"))
    }

    // MARK: vocusArticleID

    func testExtractsArticleID() {
        XCTAssertEqual(URLNormalizer.vocusArticleID("https://vocus.cc/article/67ca7699fd897800017f312c"),
                       "67ca7699fd897800017f312c")
    }

    func testArticleIDNilForNonArticle() {
        XCTAssertNil(URLNormalizer.vocusArticleID("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853"))
    }

    // MARK: canonicalVocusRoomURL

    func testCanonicalRoomURL() {
        XCTAssertEqual(
            URLNormalizer.canonicalVocusRoomURL("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853/%E6%96%87%E7%AB%A0"),
            "https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853")
    }

    func testCanonicalRoomURLAlreadyCanonical() {
        XCTAssertEqual(
            URLNormalizer.canonicalVocusRoomURL("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853"),
            "https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853")
    }

    func testCanonicalRoomURLNilForNonRoom() {
        XCTAssertNil(URLNormalizer.canonicalVocusRoomURL("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    // MARK: canonicalVocusArticleURL

    func testCanonicalArticleURL() {
        XCTAssertEqual(
            URLNormalizer.canonicalVocusArticleURL("https://vocus.cc/article/67ca7699fd897800017f312c"),
            "https://vocus.cc/article/67ca7699fd897800017f312c")
    }

    func testCanonicalArticleURLStripsQuery() {
        XCTAssertEqual(
            URLNormalizer.canonicalVocusArticleURL("https://vocus.cc/article/67ca7699fd897800017f312c?from=salon"),
            "https://vocus.cc/article/67ca7699fd897800017f312c")
    }

    func testCanonicalArticleURLNilForRoom() {
        XCTAssertNil(URLNormalizer.canonicalVocusArticleURL("https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853"))
    }

    func testCanonicalArticleURLNilForPatreon() {
        XCTAssertNil(URLNormalizer.canonicalVocusArticleURL("https://www.patreon.com/posts/12345"))
    }

    // MARK: isVocusHost

    func testVocusHostRecognized() {
        XCTAssertTrue(URLNormalizer.isVocusHost("https://vocus.cc/article/67ca7699fd897800017f312c"))
    }

    func testVocusSubdomainRecognized() {
        XCTAssertTrue(URLNormalizer.isVocusHost("https://cdn.vocus.cc/images/foo.jpg"))
    }

    func testPatreonNotVocusHost() {
        XCTAssertFalse(URLNormalizer.isVocusHost("https://www.patreon.com/posts/12345"))
    }
}
