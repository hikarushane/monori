import XCTest
@testable import MonoriCore

final class ChineseConversionMapTests: XCTestCase {
    private func lookup(_ map: String, _ char: Character) -> Character? {
        let chars = Array(map)
        var i = 0
        while i + 1 < chars.count {
            if chars[i] == char { return chars[i + 1] }
            i += 2
        }
        return nil
    }

    /// The reader script pairs the map two UTF-16 units at a time
    /// (`p[i]`, `p[i+1]`). ICU's Hant-Hans table emits a handful of
    /// supplementary-plane results (e.g. 僤 → 𫢸); one of those shifts
    /// every later pair by one unit and turns the rest of the table into
    /// garbage (大 → 鑹 was observed on an AFF chapter).
    func testMapsContainOnlySingleUTF16UnitPairs() {
        for map in [ChineseConversionMap.shared.s2tMap, ChineseConversionMap.shared.t2sMap] {
            XCTAssertEqual(map.utf16.count, map.count,
                           "every map entry must be one UTF-16 unit")
            XCTAssertEqual(map.count % 2, 0, "map must be whole pairs")
        }
    }

    func testTraditionalToSimplifiedMapsCommonCharacters() {
        let map = ChineseConversionMap.shared.t2sMap
        XCTAssertEqual(lookup(map, "無"), "无")
        XCTAssertEqual(lookup(map, "體"), "体")
        XCTAssertEqual(lookup(map, "線"), "线")
        XCTAssertNil(lookup(map, "大"), "shared characters must not be remapped")
    }

    func testSimplifiedToTraditionalMapsCommonCharacters() {
        let map = ChineseConversionMap.shared.s2tMap
        XCTAssertEqual(lookup(map, "无"), "無")
        XCTAssertEqual(lookup(map, "体"), "體")
    }
}
