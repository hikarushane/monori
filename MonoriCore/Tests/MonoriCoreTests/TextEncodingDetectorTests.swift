import XCTest
@testable import MonoriCore

final class TextEncodingDetectorTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "txt"))
        return try Data(contentsOf: url)
    }

    func testUTF8() {
        XCTAssertEqual(TextEncodingDetector.decode(Data("第一章 你好".utf8)), "第一章 你好")
    }

    func testUTF8WithBOMDropsBOM() {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("abc".utf8)
        XCTAssertEqual(TextEncodingDetector.decode(data), "abc")
    }

    func testUTF16WithBOM() throws {
        let data = try XCTUnwrap("第一章".data(using: .utf16))  // Foundation writes a BOM
        XCTAssertEqual(TextEncodingDetector.decode(data), "第一章")
    }

    func testBig5Fixture() throws {
        let s = try XCTUnwrap(TextEncodingDetector.decode(try fixture("local-big5")))
        XCTAssertTrue(s.hasPrefix("第一章 開始"), s)
        XCTAssertTrue(s.contains("她走進房間。"), s)
    }

    func testGB18030Fixture() throws {
        let s = try XCTUnwrap(TextEncodingDetector.decode(try fixture("local-gb18030")))
        XCTAssertTrue(s.hasPrefix("第一章 开始"), s)
    }

    func testGarbageReturnsNil() {
        XCTAssertNil(TextEncodingDetector.decode(Data([0x80, 0xFF, 0x80, 0xFF, 0x81, 0x00, 0xFE])))
    }
}
