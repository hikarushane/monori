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
}
