import XCTest
@testable import MonoriCore

final class BackSwipePolicyTests: XCTestCase {
    private func url(_ s: String) -> URL { URL(string: s)! }

    func testHomeFeedNeverGoesBack() {
        XCTAssertEqual(
            BackSwipePolicy.browseDecision(currentURL: url("https://www.patreon.com/home"),
                                           canGoBack: true),
            .stayAtRoot)
        XCTAssertEqual(
            BackSwipePolicy.browseDecision(currentURL: url("https://www.patreon.com/"),
                                           canGoBack: true),
            .stayAtRoot)
    }

    func testNonHomePageGoesBackWhenPossible() {
        XCTAssertEqual(
            BackSwipePolicy.browseDecision(currentURL: url("https://www.patreon.com/posts/foo-123"),
                                           canGoBack: true),
            .goBack)
    }

    func testNoHistoryIsNoop() {
        XCTAssertEqual(
            BackSwipePolicy.browseDecision(currentURL: url("https://www.patreon.com/posts/foo-123"),
                                           canGoBack: false),
            .none)
    }

    func testNilURLWithHistoryGoesBack() {
        XCTAssertEqual(BackSwipePolicy.browseDecision(currentURL: nil, canGoBack: true), .goBack)
    }
}
