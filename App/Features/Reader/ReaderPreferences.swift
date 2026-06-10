import SwiftUI

@MainActor
@Observable
final class ReaderPreferences {
    var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: "reader.fontSize") }
    }
    var readerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(readerModeEnabled, forKey: "reader.enabled") }
    }

    init() {
        let storedSize = UserDefaults.standard.integer(forKey: "reader.fontSize")
        fontSize = storedSize == 0 ? 19 : storedSize
        readerModeEnabled = UserDefaults.standard.object(forKey: "reader.enabled") as? Bool ?? true
    }
}
