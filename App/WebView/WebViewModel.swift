import Foundation
import WebKit
import os
import MonoriCore

@MainActor
@Observable
final class WebViewModel: NSObject {
    let webView: WKWebView
    let router: ScriptMessageRouter
    var currentURL: URL?
    var finishedNavigationCount = 0
    /// Mirrors WKWebView.estimatedProgress (0...1; 1 when idle) for SwiftUI.
    var loadingProgress: Double = 1
    var detectedCollection: CollectionLinkPayload?
    var isOnCollectionPage: Bool {
        guard let url = currentURL else { return false }
        return url.path.contains("/collection/")
    }
    /// Series detection only makes sense on a single post: on the home feed the
    /// first matching card link would put a meaningless banner over the feed.
    var isOnPostPage: Bool {
        guard let url = currentURL else { return false }
        return URLNormalizer.patreonPostID(url.absoluteString) != nil
    }
    var isOnGoogleDocPage: Bool {
        guard let url = currentURL else { return false }
        return URLNormalizer.isGoogleDocURL(url.absoluteString)
    }
    var isOnAO3WorkPage: Bool {
        guard let url = currentURL else { return false }
        return URLNormalizer.isAO3WorkURL(url.absoluteString)
    }
    var isOnVocusRoomPage: Bool {
        guard let url = currentURL else { return false }
        return URLNormalizer.isVocusRoomURL(url.absoluteString)
    }
    var isOnAFFForewordPage: Bool {
        guard let url = currentURL else { return false }
        return URLNormalizer.isAFFForewordURL(url.absoluteString)
    }

    private var urlObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var spaLoadingTask: Task<Void, Never>?

    private static let sharedProcessPool = WKProcessPool()

    private static let affAdBlockRules = #"""
    [
      {"trigger":{"url-filter":"googlesyndication\\.com","if-domain":["*asianfanfics.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":"doubleclick\\.net","if-domain":["*asianfanfics.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":"googletagmanager\\.com","if-domain":["*asianfanfics.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":"google-analytics\\.com","if-domain":["*asianfanfics.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":"shareasale\\.com","if-domain":["*asianfanfics.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":"cloudflareinsights\\.com","if-domain":["*asianfanfics.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","if-domain":["*asianfanfics.com"]},"action":{"type":"css-display-none","selector":"#ad-top, #bottom-ad, .ad-main, [class*='ad_responsive'], #ad_calendar_rated, .excerpt-promoted"}}
    ]
    """#

    private static func installAFFAdBlockRules(on webView: WKWebView) {
        Task { @MainActor in
            guard let list = try? await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "monori-aff-ads",
                encodedContentRuleList: affAdBlockRules
            ) else { return }
            webView.configuration.userContentController.add(list)
        }
    }

    override init() {
        let router = ScriptMessageRouter()
        self.router = router

        let config = WKWebViewConfiguration()
        config.processPool = Self.sharedProcessPool
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        for name in ScriptMessageRouter.allHandlerNames {
            config.userContentController.add(MessageShim(router: router), name: name)
        }
        // iOS gives every <a>/<img> a drag interaction, which lets Patreon's nav
        // menu entries be "picked up" and dragged around. The app never needs
        // HTML drag-and-drop, so cancel drag starts wholesale.
        config.userContentController.addUserScript(WKUserScript(
            source: "window.addEventListener('dragstart', function (e) { e.preventDefault(); }, true);",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.cardTreatment,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.ao3WorkDetect,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.vocusRoomDetect,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.affStoryDetect,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        // Hide Patreon's own top gradient loading bar (web content, not the app's
        // native ProgressView). Injected at document start so the suppressor is
        // armed before the SPA mounts the bar on the first navigation.
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.suppressLoadingBar,
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        #if DEBUG
        config.userContentController.add(LoadingBarDiagShim(), name: "monoriLoadingBarDiag")
        #endif

        #if DEBUG
        if AppEnvironment.isSmokeMode {
            config.userContentController.add(DrawerDiagShim(), name: "monoriDrawerDiag")
            config.userContentController.addUserScript(WKUserScript(
                source: JSAssets.drawerDiagnostics,
                injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        #endif

        webView = WKWebView(frame: .zero, configuration: config)
        // Render on a defined opaque surface. Without this, in dark mode the web
        // view's backdrop shows through un-backgrounded page margins as a gray
        // veil over the content (Bug 4).
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        Self.installAFFAdBlockRules(on: webView)
        // Off on purpose: the built-in gesture skips Patreon's same-document
        // (SPA) history entries, and PatreonWebView installs its own left-edge
        // swipe that calls goBack() — keeping both would double-navigate on
        // full page loads.
        webView.allowsBackForwardNavigationGestures = false

        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newURL = change.newValue ?? nil
                if newURL != self.currentURL {
                    self.currentURL = newURL
                    self.detectedCollection = nil
                    self.runCollectionDetect()
                    // Hide ads on AFF pages in browse mode
                    if let url = newURL?.absoluteString,
                       URLNormalizer.isAFFStoryURL(url) {
                        self.webView.evaluateJavaScript(ReaderStyler.affBrowseInjectionScript(), completionHandler: nil)
                    }
                    // SPA navigations (e.g. Patreon pushState) don't trigger
                    // estimatedProgress. Simulate a brief progress flash so the
                    // loading bar gives visual feedback on in-page link clicks.
                    if self.loadingProgress >= 1 {
                        self.spaLoadingTask?.cancel()
                        self.loadingProgress = 0.2
                        self.spaLoadingTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(150))
                            guard !Task.isCancelled else { return }
                            self.loadingProgress = 0.7
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            if self.loadingProgress <= 0.7 {
                                self.loadingProgress = 1
                            }
                        }
                    }
                }
            }
        }
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.loadingProgress = change.newValue ?? 1
            }
        }
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    /// Browse tab re-tap: when already on the home feed, scroll to top; otherwise
    /// return to home, preferring the web view's own history entry so Patreon
    /// restores the feed position the user left.
    func handleBrowseTabReselect() {
        if let url = currentURL, URLNormalizer.isPatreonHome(url) {
            webView.evaluateJavaScript("window.scrollTo({ top: 0, behavior: 'smooth' });",
                                       completionHandler: nil)
        } else if let home = webView.backForwardList.backList.last(where: {
            URLNormalizer.isPatreonHome($0.url)
        }) {
            webView.go(to: home)
        } else {
            load(URL(string: "https://www.patreon.com/home")!)
        }
    }

    func runCollectionDetect() {
        if isOnPostPage {
            webView.evaluateJavaScript(JSAssets.collectionDetect, completionHandler: nil)
        } else if isOnVocusRoomPage {
            webView.evaluateJavaScript(JSAssets.vocusRoomDetect, completionHandler: nil)
        } else if isOnAFFForewordPage {
            webView.evaluateJavaScript(JSAssets.affStoryDetect, completionHandler: nil)
        }
    }

    /// Fetches the current Google Doc's `/mobilebasic` HTML using the page's
    /// authenticated session and returns it directly (not via the postMessage
    /// importer channel, which forbids page content). Returns nil on non-OK.
    func fetchGoogleDocHTML() async -> String? {
        let js = """
        // Strip a trailing /edit OR /mobilebasic so we never build /mobilebasic/mobilebasic
        // when the page is already on the mobilebasic view (Drive can land there directly).
        const base = location.pathname.replace(/\\/(edit|mobilebasic).*$/, '');
        const r = await fetch(base + '/mobilebasic', { credentials: 'include' });
        if (!r.ok) { return null; }
        return await r.text();
        """
        let result = try? await webView.callAsyncJavaScript(js, contentWorld: .page)
        return result as? String
    }

    func fetchAO3NavigatePage() async -> String? {
        guard let url = currentURL?.absoluteString,
              let workID = URLNormalizer.ao3WorkID(url) else { return nil }
        return await fetchAO3Path("/works/\(workID)/navigate")
    }

    func fetchAO3ChapterPage(path: String) async -> String? {
        guard path.range(of: #"^/works/\d+/chapters/\d+$"#, options: .regularExpression) != nil
        else { return nil }
        return await fetchAO3Path(path)
    }

    private func fetchAO3Path(_ path: String) async -> String? {
        let js = """
        const r = await fetch('\(path)', { credentials: 'include' });
        if (!r.ok) return null;
        return await r.text();
        """
        return try? await webView.callAsyncJavaScript(js, contentWorld: .page) as? String
    }

    /// Expands the lazily-loaded collection list (scrolling until no new post
    /// links appear) and posts every chapter to the import handler. Returns
    /// after the page-side script has finished posting.
    @discardableResult
    func runCollectionImport() async -> Int {
        let result = try? await webView.callAsyncJavaScript(JSAssets.collectionImport,
                                                            contentWorld: .page)
        return result as? Int ?? 0
    }

    func dumpPageLinks(completion: @escaping (String) -> Void) {
        let js = """
        (function() {
            var lines = [];
            lines.push('URL: ' + location.href);
            lines.push('Title: ' + document.title);

            var allAnchors = document.querySelectorAll('a');
            var withHref = document.querySelectorAll('a[href]');
            var postsMatch = document.querySelectorAll('a[href*="/posts/"]');
            lines.push('Total <a>: ' + allAnchors.length);
            lines.push('Total <a>[href]: ' + withHref.length);
            lines.push('Match a[href*="/posts/"]: ' + postsMatch.length);

            var patterns = {};
            for (var i = 0; i < withHref.length; i++) {
                var href = withHref[i].href || '';
                if (href.indexOf('patreon.com') === -1) continue;
                try {
                    var path = new URL(href).pathname;
                    var parts = path.split('/').filter(Boolean);
                    var key = parts.length > 0 ? '/' + parts.slice(0, Math.min(parts.length, 3)).join('/') : '/';
                    patterns[key] = (patterns[key] || 0) + 1;
                } catch(e) {}
            }
            lines.push('--- URL path patterns ---');
            var keys = Object.keys(patterns).sort(function(a,b){ return patterns[b]-patterns[a]; });
            for (var k = 0; k < keys.length; k++) {
                lines.push('  ' + keys[k] + ' (' + patterns[keys[k]] + ')');
            }

            lines.push('--- Sample patreon hrefs (first 30) ---');
            var count = 0;
            for (var j = 0; j < withHref.length && count < 30; j++) {
                var h = withHref[j].href || '';
                if (h.indexOf('patreon.com') === -1) continue;
                var t = (withHref[j].textContent || '').trim().substring(0, 60);
                lines.push('  ' + h + ' | ' + t);
                count++;
            }

            return lines.join('\\n');
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            completion((result as? String) ?? "<no output>")
        }
    }
}

private final class MessageShim: NSObject, WKScriptMessageHandler {
    private let route: (String, Any) -> Void

    init(router: ScriptMessageRouter) {
        self.route = { [weak router] name, body in router?.route(name: name, body: body) }
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        route(message.name, message.body)
    }
}

#if DEBUG
/// DEBUG-only: logs DrawerDiagnostics.js events to os.Logger so smoke runs
/// capture which page event precedes the Google Drive drawer retract.
private final class DrawerDiagShim: NSObject, WKScriptMessageHandler {
    private static let log = Logger(subsystem: "dev.monori", category: "smoke-diagnostics")
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any] else { return }
        let kind = d["kind"] as? String ?? "?"
        let t = d["t"] as? Int ?? -1
        let w = d["w"] as? Int ?? -1
        let h = d["h"] as? Int ?? -1
        let vis = d["vis"] as? String ?? "?"
        let dpr = d["dpr"] as? Double ?? -1
        let sw = d["sw"] as? Int ?? -1
        let sh = d["sh"] as? Int ?? -1
        Self.log.notice("[DRAWER] page kind=\(kind, privacy: .public) t=\(t)ms size=\(w)x\(h) dpr=\(dpr, privacy: .public) screen=\(sw)x\(sh) vis=\(vis, privacy: .public)")
    }
}

/// Logs which page element the loading-bar suppressor hid, so the structural
/// signature can be verified against the live Patreon DOM during debugging.
private final class LoadingBarDiagShim: NSObject, WKScriptMessageHandler {
    private static let log = Logger(subsystem: "dev.monori", category: "smoke-diagnostics")
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any] else { return }
        let tag = d["tag"] as? String ?? "?"
        let id = d["id"] as? String ?? ""
        let cls = d["cls"] as? String ?? ""
        let role = d["role"] as? String ?? ""
        let pos = d["pos"] as? String ?? ""
        let h = d["h"] as? Int ?? -1
        let bg = d["bg"] as? String ?? ""
        let html = d["html"] as? String ?? ""
        Self.log.notice("[LOADBAR] hid tag=\(tag, privacy: .public) id=\(id, privacy: .public) cls=\(cls, privacy: .public) role=\(role, privacy: .public) pos=\(pos, privacy: .public) h=\(h) bg=\(bg, privacy: .public) html=\(html, privacy: .public)")
    }
}
#endif

extension WebViewModel: WKNavigationDelegate {
    /// `.allow` without triggering Universal Links. Google Drive registers
    /// Universal Links for `drive.google.com`; after 2FA the auth server
    /// redirects there and iOS intercepts, opening Safari instead of letting
    /// the in-app web view receive the navigation. Raw value `allow + 2`
    /// maps to WebKit's internal "allow without trying app link" policy.
    private static func allowPolicy(for url: URL) -> WKNavigationActionPolicy {
        guard let host = url.host?.lowercased(),
              NavigationPolicy.isGoogleDomain(host) else {
            return .allow
        }
        return WKNavigationActionPolicy(rawValue: WKNavigationActionPolicy.allow.rawValue + 2) ?? .allow
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let decision = NavigationPolicy.decide(url: url, isMainFrame: isMainFrame)
        #if DEBUG
        let navType: String = switch navigationAction.navigationType {
        case .linkActivated: "link"
        case .formSubmitted: "form"
        case .backForward: "back/fwd"
        case .reload: "reload"
        case .formResubmitted: "resubmit"
        case .other: "other"
        @unknown default: "unknown"
        }
        print("[NAV] \(navType) main=\(isMainFrame) → \(decision) | \(url.absoluteString.prefix(120))")
        #endif
        switch decision {
        case .allowInWebView:
            decisionHandler(Self.allowPolicy(for: url))
        case .openInSafari:
            #if DEBUG
            print("[NAV] ⚠️ OPENING IN SAFARI: \(url.absoluteString)")
            #endif
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        case .block:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentURL = webView.url
        finishedNavigationCount += 1
        detectedCollection = nil
        runCollectionDetect()
        // Hide ads on AFF pages in browse mode
        if let url = webView.url?.absoluteString,
           URLNormalizer.isAFFStoryURL(url) {
            webView.evaluateJavaScript(ReaderStyler.affBrowseInjectionScript(), completionHandler: nil)
        }
    }
}

extension WebViewModel: WKUIDelegate {
    /// Patreon renders some links with target="_blank"; without this delegate
    /// WKWebView silently ignores those taps ("nothing happens"). Route them
    /// through the same policy and load them in place instead.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            let decision = NavigationPolicy.decide(url: url, isMainFrame: true)
            #if DEBUG
            print("[NAV] window.open / _blank → \(decision) | \(url.absoluteString.prefix(120))")
            #endif
            switch decision {
            case .allowInWebView:
                webView.load(navigationAction.request)
            case .openInSafari:
                print("[NAV] ⚠️ OPENING IN SAFARI (popup): \(url.absoluteString)")
                UIApplication.shared.open(url)
            case .block:
                break
            }
        }
        return nil
    }
}
