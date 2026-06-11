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
    public static var progressTracker: String { script(named: "ProgressTracker") }
    public static var cardTreatment: String { script(named: "CardTreatment") }
}
