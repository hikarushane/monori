import Foundation

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case patreon
    case googleDocs
}

public struct SourceProvider: Identifiable, Sendable {
    public let kind: SourceKind
    public let displayName: String
    public let iconSystemName: String
    public let startURL: URL
    public var id: SourceKind { kind }

    public init(kind: SourceKind, displayName: String, iconSystemName: String, startURL: URL) {
        self.kind = kind
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.startURL = startURL
    }
}

public enum SourceRegistry {
    public static let patreon = SourceProvider(
        kind: .patreon, displayName: "Patreon", iconSystemName: "p.circle",
        startURL: URL(string: "https://www.patreon.com/home")!)

    public static let googleDrive = SourceProvider(
        kind: .googleDocs, displayName: "Google Drive", iconSystemName: "doc.richtext",
        startURL: URL(string: "https://drive.google.com")!)

    public static let all: [SourceProvider] = [patreon, googleDrive]

    public static func provider(for kind: SourceKind) -> SourceProvider {
        all.first { $0.kind == kind } ?? patreon
    }
}
