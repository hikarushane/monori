import Foundation
import Testing
@testable import MonoriCore

struct BrowserIdentityTests {
    /// Google answers 403 for `https://accounts.google.com/gsi/client` — the SDK
    /// Patreon's "Continue with Google" button is built on — whenever the User-Agent
    /// lacks either token. Losing one of them silently kills that button.
    @Test func userAgentSuffixCarriesBothSafariTokens() {
        let suffix = BrowserIdentity.userAgentSuffix
        #expect(suffix.contains("Version/"),
                "UA suffix must carry a Version/ token: \(suffix)")
        #expect(suffix.contains("Safari/"),
                "UA suffix must carry a Safari/ token: \(suffix)")
    }

    /// WKWebView appends the suffix verbatim, so a stray leading or trailing space
    /// would produce a double space and a malformed UA.
    @Test func userAgentSuffixIsTrimmed() {
        let suffix = BrowserIdentity.userAgentSuffix
        #expect(suffix == suffix.trimmingCharacters(in: .whitespaces),
                "UA suffix must not be padded: '\(suffix)'")
    }
}
