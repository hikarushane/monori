// MonoriCore/Tests/MonoriCoreTests/NavigationPolicyAFFTests.swift
import XCTest
@testable import MonoriCore

final class NavigationPolicyAFFTests: XCTestCase {
    private func decide(_ s: String) -> NavigationDecision {
        NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true)
    }

    func testAllowsAFFMainDomain() {
        XCTAssertEqual(decide("https://www.asianfanfics.com/story/view/1736914"), .allowInWebView)
    }

    func testAllowsAFFWithoutWWW() {
        XCTAssertEqual(decide("https://asianfanfics.com/story/view/1736914"), .allowInWebView)
    }

    func testAllowsAFFSubdomain() {
        XCTAssertEqual(decide("https://cdn.asianfanfics.com/images/foo.jpg"), .allowInWebView)
    }

    func testAFFSubframeAlwaysAllowed() {
        let url = URL(string: "https://www.asianfanfics.com/story/view/1736914")!
        XCTAssertEqual(NavigationPolicy.decide(url: url, isMainFrame: false), .allowInWebView)
    }
}
