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
        if host == "archiveofourown.org" || host.hasSuffix(".archiveofourown.org") {
            return .allowInWebView
        }
        if host == "vocus.cc" || host.hasSuffix(".vocus.cc") {
            return .allowInWebView
        }
        if host == "asianfanfics.com" || host.hasSuffix(".asianfanfics.com") {
            return .allowInWebView
        }
        if host == "appleid.apple.com" {
            return .allowInWebView
        }
        return .openInSafari
    }

    /// True when a window.open / target=_blank URL needs a real popup
    /// WKWebView instead of loading in the main web view. OAuth sign-in
    /// popups (Apple / Google) use response_mode=web_message and postMessage
    /// back to window.opener; loading them in place destroys the opener and
    /// the auth page refuses to render outside a popup. Everything else loads
    /// in the main web view so collection detection scripts and the import
    /// banner keep working. Exact-host match only — lookalike or suffixed
    /// hosts must not get popup treatment. See ADR-0007.
    public static func requiresPopupWindow(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "appleid.apple.com" || host == "accounts.google.com"
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
