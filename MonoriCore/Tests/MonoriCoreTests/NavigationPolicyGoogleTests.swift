import XCTest
@testable import MonoriCore

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

    func testAllowsGoogleCountryCodeTLDs() {
        XCTAssertEqual(decide("https://accounts.google.com.tw/accounts/SetSID?ssdc=1"), .allowInWebView)
        XCTAssertEqual(decide("https://accounts.google.co.jp/signin"), .allowInWebView)
        XCTAssertEqual(decide("https://drive.google.co.uk/drive"), .allowInWebView)
        XCTAssertEqual(decide("https://accounts.google.com.hk/o/oauth2"), .allowInWebView)
        XCTAssertEqual(decide("https://google.de"), .allowInWebView)
    }

    func testAllowsGoogleAPIDomains() {
        XCTAssertEqual(decide("https://clients6.google.com/x"), .allowInWebView)
        XCTAssertEqual(decide("https://content.googleapis.com/x"), .allowInWebView)
    }

    func testAllowsYouTubeDomainsInOAuthFlow() {
        XCTAssertEqual(decide("https://accounts.youtube.com/accounts/SetSID"), .allowInWebView)
        XCTAssertEqual(decide("https://youtube.com"), .allowInWebView)
        XCTAssertEqual(decide("https://www.youtube.com/watch?v=abc"), .allowInWebView)
    }

    func testRejectsLookalikeDomains() {
        XCTAssertEqual(decide("https://notyoutube.com"), .openInSafari)
        XCTAssertEqual(decide("https://notgoogle.com"), .openInSafari)
    }

    func testStillAllowsPatreonAndDefersOthers() {
        XCTAssertEqual(decide("https://www.patreon.com/home"), .allowInWebView)
        XCTAssertEqual(decide("https://example.com/x"), .openInSafari)
    }
}
