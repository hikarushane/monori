import XCTest
@testable import MonoriCore

final class NavigationPolicySlashTWTests: XCTestCase {
    func testSlashTWAllowedInWebView() {
        let decision = NavigationPolicy.decide(url: URL(string: "https://slashtw.space/forum.php?mod=viewthread&tid=123")!,
                                               isMainFrame: true)
        XCTAssertEqual(decision, .allowInWebView)
    }

    func testWaterfallSlashTWAllowedInWebView() {
        let decision = NavigationPolicy.decide(url: URL(string: "https://waterfall.slashtw.space/thread/456")!,
                                               isMainFrame: true)
        XCTAssertEqual(decision, .allowInWebView)
    }

    func testExternalFromSlashTWOpensInSafari() {
        let decision = NavigationPolicy.decide(url: URL(string: "https://example.com")!,
                                               isMainFrame: true)
        XCTAssertEqual(decision, .openInSafari)
    }
}
