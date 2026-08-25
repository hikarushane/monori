import SwiftUI

@MainActor
@Observable
final class ReaderPreferences {
    static let fontSizeRange = 14...32
    static let lineSpacingRange = 1.2...2.4
    static let lineSpacingStep = 0.1

    static let defaultFontID = "built-in.source-serif-4"

    // @Observable rewrites stored properties into computed accessors, so a
    // didSet that re-assigns its own property re-enters the setter and
    // recurses until the stack overflows (unlike plain Swift classes).
    // Clamp in explicit computed setters over private tracked storage.
    private var fontSizeStorage: Int
    private var lineSpacingStorage: Double
    private var selectedFontIDStorage: String

    var fontSize: Int {
        get { fontSizeStorage }
        set {
            fontSizeStorage = min(Self.fontSizeRange.upperBound,
                                  max(Self.fontSizeRange.lowerBound, newValue))
            UserDefaults.standard.set(fontSizeStorage, forKey: "reader.fontSize")
        }
    }

    /// CSS line-height multiplier applied to the reading column.
    var lineSpacing: Double {
        get { lineSpacingStorage }
        set {
            lineSpacingStorage = min(Self.lineSpacingRange.upperBound,
                                     max(Self.lineSpacingRange.lowerBound, newValue))
            UserDefaults.standard.set(lineSpacingStorage, forKey: "reader.lineSpacing")
        }
    }

    var selectedFontID: String {
        get { selectedFontIDStorage }
        set {
            selectedFontIDStorage = newValue
            UserDefaults.standard.set(newValue, forKey: "reader.fontID")
        }
    }

    func resetFontToDefault() {
        selectedFontID = Self.defaultFontID
    }

    init() {
        let storedSize = UserDefaults.standard.integer(forKey: "reader.fontSize")
        let size = storedSize == 0 ? 19 : storedSize
        fontSizeStorage = min(Self.fontSizeRange.upperBound,
                              max(Self.fontSizeRange.lowerBound, size))
        let storedSpacing = UserDefaults.standard.double(forKey: "reader.lineSpacing")
        let spacing = storedSpacing == 0 ? 1.75 : storedSpacing
        lineSpacingStorage = min(Self.lineSpacingRange.upperBound,
                                 max(Self.lineSpacingRange.lowerBound, spacing))
        let storedFontID = UserDefaults.standard.string(forKey: "reader.fontID")
        selectedFontIDStorage = storedFontID ?? Self.defaultFontID
    }
}
