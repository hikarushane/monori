import Foundation

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case patreon
    case googleDocs
    case ao3
    case vocus
    case asianFanfics
    case cxc
    case slashtw
    case localFile
}

public struct SourceProvider: Identifiable, Sendable {
    public let kind: SourceKind
    public let displayName: String
    public let iconSystemName: String
    public let startURL: URL
    /// False for sources that have no web page to browse (local files).
    public let browsable: Bool
    public var id: SourceKind { kind }

    public init(kind: SourceKind, displayName: String, iconSystemName: String,
                startURL: URL, browsable: Bool = true) {
        self.kind = kind
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.startURL = startURL
        self.browsable = browsable
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

    public static let vocus = SourceProvider(
        kind: .vocus, displayName: "Vocus", iconSystemName: "square.grid.2x2",
        startURL: URL(string: "https://vocus.cc")!)

    public static let asianFanfics = SourceProvider(
        kind: .asianFanfics,
        displayName: "AsianFanfics",
        iconSystemName: "book.pages",
        startURL: URL(string: "https://www.asianfanfics.com")!)

    public static let cxc = SourceProvider(
        kind: .cxc, displayName: "CXC", iconSystemName: "c.circle",
        startURL: URL(string: "https://cxc.today")!)

    public static let slashtw = SourceProvider(
        kind: .slashtw, displayName: "在水裡寫字", iconSystemName: "w.circle",
        startURL: URL(string: "https://slashtw.space")!)

    public static let localFile = SourceProvider(
        kind: .localFile, displayName: "本機檔案", iconSystemName: "folder",
        startURL: URL(string: "monori-local://import")!, browsable: false)

    public static let all: [SourceProvider] = [patreon, googleDrive, ao3, vocus, asianFanfics, cxc, slashtw, localFile]

    /// Providers that own a web view in the Browse tab.
    public static var browsable: [SourceProvider] { all.filter(\.browsable) }

    public static func provider(for kind: SourceKind) -> SourceProvider {
        switch kind {
        case .patreon: return patreon
        case .googleDocs: return googleDrive
        case .ao3: return ao3
        case .vocus: return vocus
        case .asianFanfics: return asianFanfics
        case .cxc: return cxc
        case .slashtw: return slashtw
        case .localFile: return localFile
        }
    }
}

public extension SourceKind {
    /// Sources whose collections can be re-crawled by the offscreen refresher.
    /// Google Docs stays manual by design.
    var supportsAutoCheck: Bool {
        switch self {
        case .patreon, .vocus, .asianFanfics, .ao3: return true
        case .googleDocs, .cxc, .slashtw, .localFile: return false
        }
    }
}
