import XCTest
@testable import ChapterlyCore

final class SourceKindTests: XCTestCase {
    func testRegistryHasPatreonAndGoogleDrive() {
        let kinds = SourceRegistry.all.map(\.kind)
        XCTAssertEqual(kinds, [.patreon, .googleDocs])
    }

    func testProvidersHaveStartURLsAndIcons() {
        for provider in SourceRegistry.all {
            XCTAssertFalse(provider.displayName.isEmpty)
            XCTAssertFalse(provider.iconSystemName.isEmpty)
            XCTAssertEqual(provider.startURL.scheme, "https")
        }
    }

    func testRawValueRoundTrips() {
        XCTAssertEqual(SourceKind(rawValue: "googleDocs"), .googleDocs)
        XCTAssertEqual(SourceKind.patreon.rawValue, "patreon")
    }
}
