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

    func testNavigationDismissAcceptsDeliberateLeftEdgeRightSwipe() {
        XCTAssertTrue(BackSwipePolicy.shouldDismissNavigation(
            startX: 12,
            translationX: 72,
            translationY: 8
        ))
    }

    func testNavigationDismissRejectsGestureOutsideLeftEdge() {
        XCTAssertFalse(BackSwipePolicy.shouldDismissNavigation(
            startX: 25,
            translationX: 90,
            translationY: 0
        ))
    }

    func testNavigationDismissRejectsShortLeftwardAndVerticalGestures() {
        XCTAssertFalse(BackSwipePolicy.shouldDismissNavigation(
            startX: 8,
            translationX: 59,
            translationY: 0
        ))
        XCTAssertFalse(BackSwipePolicy.shouldDismissNavigation(
            startX: 8,
            translationX: -90,
            translationY: 0
        ))
        XCTAssertFalse(BackSwipePolicy.shouldDismissNavigation(
            startX: 8,
            translationX: 90,
            translationY: 100
        ))
    }
}
