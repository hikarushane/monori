import Foundation

public enum NavigationTrace {
    public enum Surface: String, Sendable {
        case main
        case popup
    }

    public static func line(surface: Surface,
                            kind: String,
                            isMainFrame: Bool,
                            decision: NavigationDecision,
                            url: URL) -> String {
        "\(surface.rawValue) \(kind) mainFrame=\(isMainFrame) -> \(name(decision)) \(redact(url))"
    }

    public static func redact(_ url: URL) -> String {
        let scheme = url.scheme?.lowercased() ?? "unknown"
        guard let host = url.host?.lowercased() else { return "\(scheme)://<no-host>" }
        let segments = url.pathComponents.filter { $0 != "/" }
        if segments.isEmpty { return "\(scheme)://\(host)/" }
        return "\(scheme)://\(host)/<\(segments.count) segments>"
    }

    private static func name(_ decision: NavigationDecision) -> String {
        switch decision {
        case .allowInWebView: return "allowInWebView"
        case .openInSafari: return "openInSafari"
        case .block: return "block"
        }
    }
}
