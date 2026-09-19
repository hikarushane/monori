import Foundation

public enum BrowserIdentity {
    /// Appended to WKWebView's default User-Agent via
    /// `WKWebViewConfiguration.applicationNameForUserAgent`.
    ///
    /// WKWebView's stock UA stops at `Mobile/15E148` — it carries neither a
    /// `Version/` nor a `Safari/` token. Google reads that as an embedded web
    /// view and answers **403** for `https://accounts.google.com/gsi/client`,
    /// the SDK Patreon's "Continue with Google" button is built on. Without the
    /// SDK the button renders disabled and taps do nothing, which is what a beta
    /// tester hit on iOS 26.6 (2026-08-12). With both tokens present the SDK
    /// loads (200) and Patreon serves its normal login page.
    ///
    /// `Version/` is derived from the device's OS version at runtime so the
    /// token stays current across OS updates. Safari/604.1 is stable across
    /// all modern WebKit releases and does not need to track the OS.
    public static var userAgentSuffix: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "Version/\(v.majorVersion).\(v.minorVersion) Safari/604.1"
    }
}
