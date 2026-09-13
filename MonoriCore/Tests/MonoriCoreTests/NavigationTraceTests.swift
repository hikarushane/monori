import XCTest
@testable import MonoriCore

final class NavigationTraceTests: XCTestCase {

    func testDropsQueryFragmentAndPath() {
        let url = URL(string: "https://accounts.google.com/o/oauth2/auth?client_id=123&state=SECRET_STATE#id_token=SECRET_TOKEN")!
        let line = NavigationTrace.line(surface: .main, kind: "other", isMainFrame: true,
                                        decision: .allowInWebView, url: url)
        XCTAssertFalse(line.contains("SECRET_STATE"))
        XCTAssertFalse(line.contains("SECRET_TOKEN"))
        XCTAssertFalse(line.contains("?"))
        XCTAssertFalse(line.contains("#"))
        XCTAssertFalse(line.contains("oauth2"))
        XCTAssertTrue(line.contains("accounts.google.com"))
        XCTAssertTrue(line.contains("<3 segments>"))
    }

    func testRendersSurfaceKindFrameAndDecision() {
        let url = URL(string: "https://drive.google.com/drive/my-drive")!
        XCTAssertEqual(
            NavigationTrace.line(surface: .popup, kind: "other", isMainFrame: true,
                                 decision: .openInSafari, url: url),
            "popup other mainFrame=true -> openInSafari https://drive.google.com/<2 segments>")
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

    func testRedactStripsPatreonCreatorSlug() {
        let url = URL(string: "https://www.patreon.com/posts/some-secret-title-12345")!
        let redacted = NavigationTrace.redact(url)
        XCTAssertFalse(redacted.contains("some-secret-title"))
        XCTAssertFalse(redacted.contains("12345"))
        XCTAssertEqual(redacted, "https://www.patreon.com/<2 segments>")
    }

    func testRedactStripsAO3WorkPath() {
        let url = URL(string: "https://archiveofourown.org/works/98765/chapters/4321")!
        let redacted = NavigationTrace.redact(url)
        XCTAssertFalse(redacted.contains("98765"))
        XCTAssertFalse(redacted.contains("4321"))
        XCTAssertEqual(redacted, "https://archiveofourown.org/<4 segments>")
    }

    func testRedactPreservesHostOnly() {
        let url = URL(string: "https://slashtw.space/forum.php?mod=viewthread&tid=42")!
        let redacted = NavigationTrace.redact(url)
        XCTAssertTrue(redacted.contains("slashtw.space"))
        XCTAssertFalse(redacted.contains("tid=42"))
        XCTAssertFalse(redacted.contains("forum.php"))
    }
}
