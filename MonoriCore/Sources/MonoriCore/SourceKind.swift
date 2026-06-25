import Foundation

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case patreon
    case googleDocs
    case ao3
    case vocus
    case asianFanfics
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

    public static let ao3 = SourceProvider(
        kind: .ao3, displayName: "AO3", iconSystemName: "book",
        startURL: URL(string: "https://archiveofourown.org")!)

    public static let all: [SourceProvider] = [patreon, googleDrive, ao3]

    public static func provider(for kind: SourceKind) -> SourceProvider {
        switch kind {
        case .patreon: return patreon
        case .googleDocs: return googleDrive
        case .ao3: return ao3
        case .vocus, .asianFanfics: return patreon  // placeholder until Task 6 wires them
        }
    }
}
