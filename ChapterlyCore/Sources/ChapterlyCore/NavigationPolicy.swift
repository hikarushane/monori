import Foundation

public enum NavigationDecision: Equatable {
    case allowInWebView
    case openInSafari
    case block
}

public enum NavigationPolicy {
    public static func decide(url: URL, isMainFrame: Bool) -> NavigationDecision {
        guard isMainFrame else { return .allowInWebView }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return .block
        }
        guard let host = url.host?.lowercased() else { return .block }
        if host == "patreon.com" || host.hasSuffix(".patreon.com") {
            return .allowInWebView
        }
        let googleSuffixes = [".google.com", ".googleusercontent.com", ".gstatic.com"]
        if host == "google.com" || googleSuffixes.contains(where: { host.hasSuffix($0) }) {
            return .allowInWebView
        }
        return .openInSafari
    }
}
