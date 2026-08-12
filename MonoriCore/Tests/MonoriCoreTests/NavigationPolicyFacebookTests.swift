import Foundation
import Testing
@testable import MonoriCore

/// Patreon's "Continue with Facebook" opens `m.facebook.com/…/dialog/oauth`
/// through `window.open`. Before these tests the host was missing from both
/// allowlists, so the popup was pushed out to Safari and the login could never
/// post back to its opener — the failure mode ADR-0007 predicted for the next
/// OAuth provider.
struct NavigationPolicyFacebookTests {
    private func decide(_ urlString: String) -> NavigationDecision {
        NavigationPolicy.decide(url: URL(string: urlString)!, isMainFrame: true)
    }

    @Test func facebookAuthHostsLoadInWebView() {
        let urls = [
            "https://m.facebook.com/v10.0/dialog/oauth?app_id=130127590512253",
            "https://www.facebook.com/v10.0/dialog/oauth?app_id=130127590512253",
            "https://facebook.com/login",
            // The OAuth redirect_uri Facebook bounces the popup through.
            "https://staticxx.facebook.com/x/connect/xd_arbiter/?version=46",
        ]
        for urlString in urls {
            #expect(decide(urlString) == .allowInWebView,
                    "Facebook auth URL should stay in the app: \(urlString)")
        }
    }

    @Test func facebookLookalikeHostsGoToSafari() {
        let lookalikes = [
            "https://m.facebook.com.evil.example/v10.0/dialog/oauth",
            "https://evilfacebook.com/v10.0/dialog/oauth",
        ]
        for urlString in lookalikes {
            #expect(decide(urlString) == .openInSafari,
                    "Lookalike host must not be treated as Facebook: \(urlString)")
        }
    }

    @Test func facebookDialogHostsRequirePopupWindow() {
        let dialogURLs = [
            "https://m.facebook.com/v10.0/dialog/oauth?app_id=130127590512253",
            "https://www.facebook.com/v10.0/dialog/oauth?app_id=130127590512253",
            "https://M.FACEBOOK.COM/v10.0/dialog/oauth",
        ]
        for urlString in dialogURLs {
            #expect(NavigationPolicy.requiresPopupWindow(URL(string: urlString)!),
                    "Facebook OAuth dialog needs window.opener: \(urlString)")
        }
    }

    @Test func facebookLookalikeHostsDoNotRequirePopupWindow() {
        let lookalikes = [
            "https://m.facebook.com.evil.example/v10.0/dialog/oauth",
            "https://evilm.facebook.com/v10.0/dialog/oauth",
        ]
        for urlString in lookalikes {
            #expect(!NavigationPolicy.requiresPopupWindow(URL(string: urlString)!),
                    "Lookalike host must not get popup treatment: \(urlString)")
        }
    }
}
