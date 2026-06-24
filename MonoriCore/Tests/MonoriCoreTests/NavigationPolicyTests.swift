import XCTest
@testable import MonoriCore

final class NavigationPolicyTests: XCTestCase {
    func testPatreonMainFrameAllowed() {
        for s in ["https://www.patreon.com/home",
                  "https://patreon.com/posts/x-1",
                  "https://auth.patreon.com/login"] {
            XCTAssertEqual(NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true),
                           .allowInWebView, s)
        }
    }

    func testExternalMainFrameOpensSafari() {
        for s in ["https://example.com", "https://twitter.com/someone", "https://patreon.com.evil.com/x"] {
            XCTAssertEqual(NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true),
                           .openInSafari, s)
        }
    }

    func testSubframesAlwaysAllowed() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "https://cdn.example.com/img.png")!,
                                               isMainFrame: false),
                       .allowInWebView)
    }

    func testNonHTTPSchemesBlocked() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "ftp://patreon.com/x")!, isMainFrame: true),
                       .block)
    }
}
