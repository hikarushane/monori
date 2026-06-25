import XCTest
@testable import MonoriCore

final class NavigationPolicyVocusTests: XCTestCase {
    private func decide(_ s: String) -> NavigationDecision {
        NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true)
    }

    func testAllowsVocusMainDomain() {
        XCTAssertEqual(decide("https://vocus.cc/salon/abc123"), .allowInWebView)
    }

    func testAllowsVocusWWW() {
        XCTAssertEqual(decide("https://www.vocus.cc/article/abc123"), .allowInWebView)
    }

    func testAllowsVocusAPI() {
        XCTAssertEqual(decide("https://api.vocus.cc/api/articles"), .allowInWebView)
    }

    func testVocusSubframeAlwaysAllowed() {
        let url = URL(string: "https://vocus.cc/salon/abc123")!
        XCTAssertEqual(NavigationPolicy.decide(url: url, isMainFrame: false), .allowInWebView)
    }
}
