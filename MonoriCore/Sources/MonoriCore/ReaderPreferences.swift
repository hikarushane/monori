import Foundation
import Observation

public enum ChineseConversion: String, Codable, CaseIterable, Sendable {
    case off
    case auto
    case toTraditional
    case toSimplified

    public var resolved: ChineseConversion {
        guard self == .auto else { return self }
        guard let lang = Locale.preferredLanguages.first else { return .off }
        if lang.hasPrefix("zh-Hant") { return .toTraditional }
        if lang.hasPrefix("zh-Hans") { return .toSimplified }
        return .off
    }

    public var displayName: String {
        switch self {
        case .auto:
            switch resolved {
            case .toTraditional: return "自動（繁體）"
            case .toSimplified: return "自動（简体）"
            default: return "自動"
            }
        case .toTraditional: return "繁體"
        case .toSimplified: return "简体"
        case .off: return "不轉換"
        }
    }
}

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
        static let chineseConversion = "reader.chineseConversion"
    }

    @ObservationIgnored private let defaults: UserDefaults
    private var fontSizeStorage: Int
    private var lineSpacingStorage: Double
    private var selectedFontIDStorage: String
    private var chineseConversionStorage: String

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

    public var chineseConversion: ChineseConversion {
        get { ChineseConversion(rawValue: chineseConversionStorage) ?? .off }
        set {
            chineseConversionStorage = newValue.rawValue
            defaults.set(newValue.rawValue, forKey: Key.chineseConversion)
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

        chineseConversionStorage = defaults.string(forKey: Key.chineseConversion)
            ?? ChineseConversion.auto.rawValue
    }

    public func resetFontToDefault() {
        selectedFontID = Self.defaultFontID
    }
}
