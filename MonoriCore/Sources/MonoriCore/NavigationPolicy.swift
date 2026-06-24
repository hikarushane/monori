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
        if isGoogleDomain(host) {
            return .allowInWebView
        }
        return .openInSafari
    }

    /// Matches any Google-owned domain including country-code TLDs
    /// (google.com, google.com.tw, google.co.jp, etc.) and their
    /// companion domains (googleusercontent.com, gstatic.com, googleapis.com).
    public static func isGoogleDomain(_ host: String) -> Bool {
        let companions = [".googleusercontent.com", ".gstatic.com", ".googleapis.com"]
        if companions.contains(where: { host.hasSuffix($0) }) { return true }
        let parts = host.split(separator: ".")
        guard let idx = parts.lastIndex(where: { $0 == "google" }) else { return false }
        let tldCount = parts.count - Int(idx) - 1
        return tldCount >= 1 && tldCount <= 2
    }
}
