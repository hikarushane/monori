import Foundation
import Observation

@MainActor
@Observable
public final class ReaderPreferences {
    public static let fontSizeRange = 14...48
    public static let lineSpacingRange = 1.2...2.4
    public static let lineSpacingStep = 0.1
    public static let defaultFontID = "built-in.source-serif-4"

    private enum Key {
        static let fontSize = "reader.fontSize"
        static let lineSpacing = "reader.lineSpacing"
        static let fontID = "reader.fontID"
    }

    @ObservationIgnored private let defaults: UserDefaults
    private var fontSizeStorage: Int
    private var lineSpacingStorage: Double
    private var selectedFontIDStorage: String

    public var fontSize: Int {
        get { fontSizeStorage }
        set {
            fontSizeStorage = min(Self.fontSizeRange.upperBound,
                                  max(Self.fontSizeRange.lowerBound, newValue))
            defaults.set(fontSizeStorage, forKey: Key.fontSize)
        }
    }

    public var lineSpacing: Double {
        get { lineSpacingStorage }
        set {
            lineSpacingStorage = min(Self.lineSpacingRange.upperBound,
                                     max(Self.lineSpacingRange.lowerBound, newValue))
            defaults.set(lineSpacingStorage, forKey: Key.lineSpacing)
        }
    }

    public var selectedFontID: String {
        get { selectedFontIDStorage }
        set {
            selectedFontIDStorage = newValue
            defaults.set(newValue, forKey: Key.fontID)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedSize = defaults.integer(forKey: Key.fontSize)
        let size = storedSize == 0 ? 19 : storedSize
        fontSizeStorage = min(Self.fontSizeRange.upperBound,
                              max(Self.fontSizeRange.lowerBound, size))

        let storedSpacing = defaults.double(forKey: Key.lineSpacing)
        let spacing = storedSpacing == 0 ? 1.75 : storedSpacing
        lineSpacingStorage = min(Self.lineSpacingRange.upperBound,
                                 max(Self.lineSpacingRange.lowerBound, spacing))

        selectedFontIDStorage = defaults.string(forKey: Key.fontID)
            ?? Self.defaultFontID
    }

    public func resetFontToDefault() {
        selectedFontID = Self.defaultFontID
    }
}
