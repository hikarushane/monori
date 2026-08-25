import Foundation

struct ReaderFontDescriptor: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case builtIn
        case imported
    }

    let id: String
    let kind: Kind
    let displayName: String
    let storedFileName: String?

    static let builtInDefault = ReaderFontDescriptor(
        id: "built-in.source-serif-4",
        kind: .builtIn,
        displayName: "Source Serif 4",
        storedFileName: nil)
}
