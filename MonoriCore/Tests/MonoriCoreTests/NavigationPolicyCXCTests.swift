import XCTest
@testable import MonoriCore

final class NavigationPolicyCXCTests: XCTestCase {
    func testCXCMainDomainAllowed() {
        let decision = NavigationPolicy.decide(url: URL(string: "https://cxc.today/zh/@foo/work/123")!,
                                               isMainFrame: true)
        XCTAssertEqual(decision, .allowInWebView)
    }

    func testCXCSubdomainAllowed() {
        let decision = NavigationPolicy.decide(url: URL(string: "https://bl.cxc.today/zh/@bar/work/456")!,
                                               isMainFrame: true)
        XCTAssertEqual(decision, .allowInWebView)
    }

    func testExternalFromCXCOpensInSafari() {
        let decision = NavigationPolicy.decide(url: URL(string: "https://example.com")!,
                                               isMainFrame: true)
        XCTAssertEqual(decision, .openInSafari)
    }
}
