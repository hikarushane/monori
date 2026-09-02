import Foundation

public enum JSAssets {
    public static func script(named name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing bundled script \(name).js")
            return ""
        }
        return source
    }

    public static var collectionImport: String { script(named: "CollectionImport") }
    public static var collectionDetect: String { script(named: "CollectionDetect") }
    public static var cardTreatment: String { script(named: "CardTreatment") }
    public static var drawerDiagnostics: String { script(named: "DrawerDiagnostics") }
    public static var suppressLoadingBar: String { script(named: "SuppressLoadingBar") }
    public static var ao3WorkDetect: String { script(named: "AO3WorkDetect") }
    public static var ao3WorkMeta: String { script(named: "AO3WorkMeta") }
    public static var ao3WorkContent: String { script(named: "AO3WorkContent") }
    public static var vocusRoomDetect: String { script(named: "VocusRoomDetect") }
    public static var vocusRoomImport: String { script(named: "VocusRoomImport") }
    public static var affStoryDetect: String { script(named: "AFFStoryDetect") }
    public static var affStoryImport: String { script(named: "AFFStoryImport") }
    public static var cxcWorkDetect: String { script(named: "CXCWorkDetect") }
    public static var cxcWorkImport: String { script(named: "CXCWorkImport") }
}
