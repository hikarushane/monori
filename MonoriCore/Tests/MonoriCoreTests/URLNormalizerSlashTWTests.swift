import XCTest
@testable import MonoriCore

final class URLNormalizerSlashTWTests: XCTestCase {

    // MARK: isSlashTWHost

    func testIsSlashTWHost() {
        XCTAssertTrue(URLNormalizer.isSlashTWHost(URL(string: "https://slashtw.space")!))
        XCTAssertTrue(URLNormalizer.isSlashTWHost(URL(string: "https://waterfall.slashtw.space")!))
        XCTAssertFalse(URLNormalizer.isSlashTWHost(URL(string: "https://example.com")!))
    }

    func testIsSlashTWHostCaseInsensitive() {
        XCTAssertTrue(URLNormalizer.isSlashTWHost(URL(string: "https://SLASHTW.SPACE")!))
        XCTAssertTrue(URLNormalizer.isSlashTWHost(URL(string: "https://WATERFALL.SLASHTW.SPACE")!))
    }

    func testIsSlashTWHostFalseForLookalikeDomain() {
        XCTAssertFalse(URLNormalizer.isSlashTWHost(URL(string: "https://evilslashtw.space")!))
        XCTAssertFalse(URLNormalizer.isSlashTWHost(URL(string: "https://slashtw.space.evil.com")!))
    }

    // MARK: slashtwThreadID

    func testSlashTWThreadIDFromWaterfall() {
        XCTAssertEqual(
            URLNormalizer.slashtwThreadID(URL(string: "https://waterfall.slashtw.space/thread/4118")!),
            "4118")
    }

    func testSlashTWThreadIDFromDiscuz() {
        XCTAssertEqual(
            URLNormalizer.slashtwThreadID(
                URL(string: "https://slashtw.space/forum.php?mod=viewthread&tid=4118")!),
            "4118")
    }

    func testSlashTWThreadIDNilForNonNumericWaterfallID() {
        XCTAssertNil(URLNormalizer.slashtwThreadID(URL(string: "https://waterfall.slashtw.space/thread/abc")!))
    }

    func testSlashTWThreadIDNilForNonNumericDiscuzTid() {
        XCTAssertNil(URLNormalizer.slashtwThreadID(
            URL(string: "https://slashtw.space/forum.php?mod=viewthread&tid=abc")!))
    }

    func testSlashTWThreadIDNilForNonSlashTWHost() {
        XCTAssertNil(URLNormalizer.slashtwThreadID(URL(string: "https://example.com/thread/4118")!))
    }

    func testSlashTWThreadIDNilForDiscuzWrongMod() {
        XCTAssertNil(URLNormalizer.slashtwThreadID(
            URL(string: "https://slashtw.space/forum.php?mod=forumdisplay&fid=2")!))
    }

    func testSlashTWThreadIDNilForDiscuzMissingTid() {
        XCTAssertNil(URLNormalizer.slashtwThreadID(
            URL(string: "https://slashtw.space/forum.php?mod=viewthread")!))
    }

    func testSlashTWThreadIDNilForWaterfallMissingID() {
        XCTAssertNil(URLNormalizer.slashtwThreadID(URL(string: "https://waterfall.slashtw.space/thread")!))
    }

    func testSlashTWThreadIDNilForHostRoot() {
        XCTAssertNil(URLNormalizer.slashtwThreadID(URL(string: "https://slashtw.space")!))
    }

    // MARK: isSlashTWThreadURL

    func testIsSlashTWThreadURL() {
        XCTAssertTrue(URLNormalizer.isSlashTWThreadURL(URL(string: "https://waterfall.slashtw.space/thread/4118")!))
        XCTAssertTrue(URLNormalizer.isSlashTWThreadURL(
            URL(string: "https://slashtw.space/forum.php?mod=viewthread&tid=4118")!))
        XCTAssertFalse(URLNormalizer.isSlashTWThreadURL(URL(string: "https://slashtw.space")!))
        XCTAssertFalse(URLNormalizer.isSlashTWThreadURL(URL(string: "https://example.com/thread/4118")!))
    }

    // MARK: canonicalSlashTWThreadURL

    func testCanonicalSlashTWThreadURL() {
        let canonical = URLNormalizer.canonicalSlashTWThreadURL(
            URL(string: "https://slashtw.space/forum.php?mod=viewthread&tid=4118")!)
        XCTAssertEqual(canonical?.absoluteString, "https://waterfall.slashtw.space/thread/4118")
    }

    func testCanonicalSlashTWThreadURLAlreadyCanonical() {
        let canonical = URLNormalizer.canonicalSlashTWThreadURL(
            URL(string: "https://waterfall.slashtw.space/thread/4118")!)
        XCTAssertEqual(canonical?.absoluteString, "https://waterfall.slashtw.space/thread/4118")
    }

    func testCanonicalSlashTWThreadURLNilForNonThreadURL() {
        XCTAssertNil(URLNormalizer.canonicalSlashTWThreadURL(URL(string: "https://slashtw.space")!))
    }

    func testCanonicalSlashTWThreadURLNilForNonSlashTWHost() {
        XCTAssertNil(URLNormalizer.canonicalSlashTWThreadURL(URL(string: "https://example.com/thread/4118")!))
    }
}
