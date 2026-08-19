import XCTest
@testable import MonoriCore

final class NavigationTraceTests: XCTestCase {

    func testDropsQueryAndFragment() {
        let url = URL(string: "https://accounts.google.com/o/oauth2/auth?client_id=123&state=SECRET_STATE#id_token=SECRET_TOKEN")!
        let line = NavigationTrace.line(surface: .main, kind: "other", isMainFrame: true,
                                        decision: .allowInWebView, url: url)
        XCTAssertFalse(line.contains("SECRET_STATE"))
        XCTAssertFalse(line.contains("SECRET_TOKEN"))
        XCTAssertFalse(line.contains("?"))
        XCTAssertFalse(line.contains("#"))
        XCTAssertTrue(line.contains("https://accounts.google.com/o/oauth2/auth"))
    }

    func testRendersSurfaceKindFrameAndDecision() {
        let url = URL(string: "https://drive.google.com/drive/my-drive")!
        XCTAssertEqual(
            NavigationTrace.line(surface: .popup, kind: "other", isMainFrame: true,
                                 decision: .openInSafari, url: url),
            "popup other mainFrame=true -> openInSafari https://drive.google.com/drive/my-drive")
    }

    func testNamesEveryDecision() {
        let url = URL(string: "https://www.patreon.com/home")!
        func line(_ d: NavigationDecision) -> String {
            NavigationTrace.line(surface: .main, kind: "link", isMainFrame: true, decision: d, url: url)
        }
        XCTAssertTrue(line(.allowInWebView).contains("-> allowInWebView"))
        XCTAssertTrue(line(.openInSafari).contains("-> openInSafari"))
        XCTAssertTrue(line(.block).contains("-> block"))
    }

    func testRootPathRendersAsSlash() {
        XCTAssertEqual(NavigationTrace.redact(URL(string: "https://drive.google.com")!),
                       "https://drive.google.com/")
    }

    func testHostlessURLIsRenderedWithoutLeakingTheRest() {
        let line = NavigationTrace.redact(URL(string: "about:blank")!)
        XCTAssertEqual(line, "about://<no-host>")
    }
}
