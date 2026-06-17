import XCTest
@testable import ChapterlyCore

final class NavigationPolicyGoogleTests: XCTestCase {
    private func decide(_ s: String) -> NavigationDecision {
        NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true)
    }

    func testAllowsGoogleDocsAndDriveAndAccounts() {
        XCTAssertEqual(decide("https://docs.google.com/document/d/ABC/edit"), .allowInWebView)
        XCTAssertEqual(decide("https://drive.google.com/drive/my-drive"), .allowInWebView)
        XCTAssertEqual(decide("https://accounts.google.com/signin"), .allowInWebView)
        XCTAssertEqual(decide("https://lh3.googleusercontent.com/x"), .allowInWebView)
    }

    func testStillAllowsPatreonAndDefersOthers() {
        XCTAssertEqual(decide("https://www.patreon.com/home"), .allowInWebView)
        XCTAssertEqual(decide("https://example.com/x"), .openInSafari)
    }
}
