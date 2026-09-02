import XCTest
@testable import MonoriCore

@MainActor
final class ReaderPreferencesTests: XCTestCase {
    private func isolatedDefaults() -> (UserDefaults, String) {
        let name = "dev.monori.tests.reader-preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    func testDefaultsMatchReaderContract() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let preferences = ReaderPreferences(defaults: defaults)

        XCTAssertEqual(preferences.fontSize, 19)
        XCTAssertEqual(preferences.lineSpacing, 1.75, accuracy: 0.001)
        XCTAssertEqual(preferences.selectedFontID, ReaderPreferences.defaultFontID)
    }

    func testAllReaderPreferencesSurviveOwnerRecreation() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let firstOwner = ReaderPreferences(defaults: defaults)
        firstOwner.fontSize = 26
        firstOwner.lineSpacing = 2.1
        firstOwner.selectedFontID = "imported.test-font"

        let nextOwner = ReaderPreferences(defaults: defaults)
        XCTAssertEqual(nextOwner.fontSize, 26)
        XCTAssertEqual(nextOwner.lineSpacing, 2.1, accuracy: 0.001)
        XCTAssertEqual(nextOwner.selectedFontID, "imported.test-font")
    }

    func testOutOfRangeValuesAreClampedAndPersisted() {
        let (defaults, name) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let firstOwner = ReaderPreferences(defaults: defaults)
        firstOwner.fontSize = 100
        firstOwner.lineSpacing = 0.2

        let nextOwner = ReaderPreferences(defaults: defaults)
        XCTAssertEqual(nextOwner.fontSize, 48)
        XCTAssertEqual(nextOwner.lineSpacing, 1.2, accuracy: 0.001)
    }
}
