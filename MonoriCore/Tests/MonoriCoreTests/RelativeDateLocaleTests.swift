// MonoriCore/Tests/MonoriCoreTests/RelativeDateLocaleTests.swift
import Foundation
import Testing

@Suite("Relative date locale")
struct RelativeDateLocaleTests {
    @Test("zh-Hant locale produces Chinese relative date")
    func relativeDateInChinese() {
        let fiveMinutesAgo = Date.now.addingTimeInterval(-300)
        let formatted = fiveMinutesAgo.formatted(
            .relative(presentation: .named)
            .locale(Locale(identifier: "zh-Hant"))
        )
        // Must contain at least one CJK character — not pure ASCII/English
        let hasCJK = formatted.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||   // CJK Unified
            (0x3400...0x4DBF).contains(scalar.value)      // CJK Extension A
        }
        #expect(hasCJK, "Expected Chinese output, got: \(formatted)")
    }

    @Test("default locale may produce English — documents the bug")
    func defaultLocaleIsNotChinese() {
        // This test documents that without an explicit locale,
        // the formatter may produce English in an app without
        // zh-Hant.lproj. If this test starts failing (i.e. the
        // default suddenly produces Chinese), the explicit locale
        // pin is still harmless but this documents the change.
        let recent = Date.now.addingTimeInterval(-60)
        let formatted = recent.formatted(.relative(presentation: .named))
        // We just verify it runs without crashing.
        // The output language depends on the test runner's bundle
        // localizations, so we don't assert on content here.
        #expect(!formatted.isEmpty)
    }
}
