import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: "跟隨系統"
        case .light: "淺色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
final class AppPreferences {
    private var appearanceStorage: String

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceStorage) ?? .system }
        set {
            appearanceStorage = newValue.rawValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "app.appearance")
        }
    }

    init() {
        appearanceStorage = UserDefaults.standard.string(forKey: "app.appearance")
            ?? AppearanceMode.system.rawValue
    }
}
