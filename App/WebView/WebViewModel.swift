import Foundation
import WebKit
import ChapterlyCore

@MainActor
@Observable
final class WebViewModel: NSObject {
    let webView: WKWebView
    let router: ScriptMessageRouter
    var currentURL: URL?
    var finishedNavigationCount = 0
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

    private var urlObservation: NSKeyValueObservation?

    override init() {
        let router = ScriptMessageRouter()
        self.router = router

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        for name in ScriptMessageRouter.allHandlerNames {
            config.userContentController.add(MessageShim(router: router), name: name)
        }
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.progressTracker,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        // iOS gives every <a>/<img> a drag interaction, which lets Patreon's nav
        // menu entries be "picked up" and dragged around. The app never needs
        // HTML drag-and-drop, so cancel drag starts wholesale.
        config.userContentController.addUserScript(WKUserScript(
            source: "window.addEventListener('dragstart', function (e) { e.preventDefault(); }, true);",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newURL = change.newValue ?? nil
                if newURL != self.currentURL {
                    self.currentURL = newURL
                    self.detectedCollection = nil
                    self.runCollectionDetect()
                }
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
        guard isOnPostPage else { return }
        webView.evaluateJavaScript(JSAssets.collectionDetect, completionHandler: nil)
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

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        switch NavigationPolicy.decide(url: url, isMainFrame: isMainFrame) {
        case .allowInWebView:
            decisionHandler(.allow)
        case .openInSafari:
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
    }
}
