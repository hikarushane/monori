import Foundation
import Testing
@testable import MonoriCore

struct NavigationPolicyPopupTests {
    @Test func vocusRoomURLShouldBeIntercepted() {
        let roomURLs = [
            "https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853",
            "https://vocus.cc/salon/test-salon/room/abc123def456789012345678",
        ]
        for urlString in roomURLs {
            #expect(URLNormalizer.isVocusRoomURL(urlString),
                    "Room URL should be intercepted: \(urlString)")
        }
    }

    @Test func nonRoomVocusURLShouldNotBeIntercepted() {
        let nonRoomURLs = [
            "https://vocus.cc/salon/Aliens",
            "https://vocus.cc/article/69c87373694f1e8d97d07853",
            "https://vocus.cc/",
            "https://patreon.com/posts/12345",
        ]
        for urlString in nonRoomURLs {
            #expect(!URLNormalizer.isVocusRoomURL(urlString),
                    "Non-room URL should not be intercepted: \(urlString)")
        }
    }

    @Test func oauthPopupURLsRequirePopupWindow() {
        let oauthURLs = [
            "https://appleid.apple.com/auth/authorize?client_id=cc.vocus.web&response_mode=web_message",
            "https://accounts.google.com/o/oauth2/v2/auth?client_id=x",
            "https://ACCOUNTS.GOOGLE.COM/signin/oauth",
        ]
        for urlString in oauthURLs {
            let url = URL(string: urlString)!
            #expect(NavigationPolicy.requiresPopupWindow(url),
                    "OAuth URL should get a real popup window: \(urlString)")
        }
    }

    @Test func contentURLsDoNotRequirePopupWindow() {
        let contentURLs = [
            "https://vocus.cc/salon/Aliens/room/69c87373694f1e8d97d07853",
            "https://docs.google.com/document/d/abc123/edit",
            "https://drive.google.com/file/d/xyz789/view",
            "https://www.patreon.com/posts/12345",
            "https://archiveofourown.org/works/123456",
            "https://www.asianfanfics.com/story/view/1234567",
        ]
        for urlString in contentURLs {
            let url = URL(string: urlString)!
            #expect(!NavigationPolicy.requiresPopupWindow(url),
                    "Content URL should load in the main web view: \(urlString)")
        }
    }

    @Test func lookalikeHostsDoNotRequirePopupWindow() {
        let lookalikes = [
            "https://appleid.apple.com.evil.example/auth/authorize",
            "https://evilaccounts.google.com/o/oauth2/v2/auth",
        ]
        for urlString in lookalikes {
            let url = URL(string: urlString)!
            #expect(!NavigationPolicy.requiresPopupWindow(url),
                    "Lookalike host must not get popup treatment: \(urlString)")
        }
    }
}
