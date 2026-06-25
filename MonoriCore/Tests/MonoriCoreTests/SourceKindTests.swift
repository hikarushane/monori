import XCTest
@testable import MonoriCore

final class SourceKindTests: XCTestCase {
    func testRegistryHasAllSources() {
        let kinds = SourceRegistry.all.map(\.kind)
        XCTAssertEqual(kinds, [.patreon, .googleDocs, .ao3, .vocus])
    }

    func testVocusProviderLookup() {
        let provider = SourceRegistry.provider(for: .vocus)
        XCTAssertEqual(provider.kind, .vocus)
        XCTAssertEqual(provider.displayName, "Vocus")
        XCTAssertEqual(provider.startURL.host, "vocus.cc")
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

    func testAO3CodableRoundtrip() throws {
        let data = try JSONEncoder().encode(SourceKind.ao3)
        let decoded = try JSONDecoder().decode(SourceKind.self, from: data)
        XCTAssertEqual(decoded, .ao3)
    }

    func testVocusCodableRoundtrip() throws {
        let data = try JSONEncoder().encode(SourceKind.vocus)
        let decoded = try JSONDecoder().decode(SourceKind.self, from: data)
        XCTAssertEqual(decoded, .vocus)
    }

    func testAsianFanficsCodableRoundtrip() throws {
        let data = try JSONEncoder().encode(SourceKind.asianFanfics)
        let decoded = try JSONDecoder().decode(SourceKind.self, from: data)
        XCTAssertEqual(decoded, .asianFanfics)
    }

    func testAO3RawValue() {
        XCTAssertEqual(SourceKind.ao3.rawValue, "ao3")
        XCTAssertEqual(SourceKind.vocus.rawValue, "vocus")
        XCTAssertEqual(SourceKind.asianFanfics.rawValue, "asianFanfics")
    }

    func testAO3ProviderLookup() {
        let provider = SourceRegistry.provider(for: .ao3)
        XCTAssertEqual(provider.kind, .ao3)
        XCTAssertEqual(provider.displayName, "AO3")
        XCTAssertEqual(provider.startURL.host, "archiveofourown.org")
    }
}
