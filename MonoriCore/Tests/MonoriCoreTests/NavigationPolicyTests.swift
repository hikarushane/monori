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

    func testLocalFileSchemeMainFrameAllowed() {
        let base = URL(string: LocalFileIdentity.sourceURLString(fileName: "我的小說.epub"))!
        XCTAssertEqual(NavigationPolicy.decide(url: base, isMainFrame: true), .allowInWebView)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "monori-local://import")!, isMainFrame: true),
                       .allowInWebView)
    }

    func testOtherCustomSchemesStayBlocked() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "monori-other://x")!, isMainFrame: true), .block)
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "file:///tmp/x.html")!, isMainFrame: true), .block)
    }
}
