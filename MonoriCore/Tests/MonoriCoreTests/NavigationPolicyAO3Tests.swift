import XCTest
@testable import MonoriCore

final class NavigationPolicyAO3Tests: XCTestCase {
    private func decide(_ s: String) -> NavigationDecision {
        NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true)
    }

    func testAllowsAO3MainDomain() {
        XCTAssertEqual(decide("https://archiveofourown.org/works/12345"), .allowInWebView)
    }

    func testAllowsAO3Subdomain() {
        XCTAssertEqual(decide("https://download.archiveofourown.org/downloads/12345"), .allowInWebView)
    }

    func testAO3SubframeAlwaysAllowed() {
        let url = URL(string: "https://archiveofourown.org/works/12345")!
        XCTAssertEqual(NavigationPolicy.decide(url: url, isMainFrame: false), .allowInWebView)
    }

    func testAO3WithWWW() {
        XCTAssertEqual(decide("https://www.archiveofourown.org/works/12345"), .allowInWebView)
    }
}
