import SwiftUI

@MainActor
@Observable
final class ReaderPreferences {
    static let fontSizeRange = 14...32
    static let lineSpacingRange = 1.2...2.4
    static let lineSpacingStep = 0.1

    var fontSize: Int {
        didSet {
            fontSize = min(Self.fontSizeRange.upperBound,
                           max(Self.fontSizeRange.lowerBound, fontSize))
            UserDefaults.standard.set(fontSize, forKey: "reader.fontSize")
        }
    }

    /// CSS line-height multiplier applied to the reading column.
    var lineSpacing: Double {
        didSet {
            lineSpacing = min(Self.lineSpacingRange.upperBound,
                              max(Self.lineSpacingRange.lowerBound, lineSpacing))
            UserDefaults.standard.set(lineSpacing, forKey: "reader.lineSpacing")
        }
    }

    init() {
        let storedSize = UserDefaults.standard.integer(forKey: "reader.fontSize")
        fontSize = storedSize == 0 ? 19 : storedSize
        let storedSpacing = UserDefaults.standard.double(forKey: "reader.lineSpacing")
        lineSpacing = storedSpacing == 0 ? 1.75 : storedSpacing
    }
}
