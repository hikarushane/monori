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
    /// `Version/` tracks the OS token WebKit itself reports (currently
    /// `iPhone OS 18_7`), not the device's iOS release — keep the two in step if
    /// WebKit ever moves its frozen value.
    public static let userAgentSuffix = "Version/18.7 Safari/604.1"
}
