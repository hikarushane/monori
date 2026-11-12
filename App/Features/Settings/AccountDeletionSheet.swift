import SwiftUI
import WebKit
import MonoriCore

struct AccountDeletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var popups = SignInPopupHost()

    var body: some View {
        NavigationStack {
            AccountDeletionWebView(popups: popups)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Delete Patreon Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .sheet(isPresented: Binding(
            get: { popups.popupWebView != nil },
            set: { if !$0 { popups.popupWebView = nil } }
        )) {
            if let popup = popups.popupWebView {
                PopupWebSheet(webView: popup)
            }
        }
    }
}

/// The Privacy Center asks for a Patreon sign-in before Erase, and Patreon's
/// Apple / Google / Facebook buttons open their OAuth page with window.open and
/// post the result back to window.opener. A web view without a UI delegate
/// answers window.open with no window, so Patreon shows "an error occurred"
/// instead of signing in. Same popup rule as the browse web view (ADR-0007):
/// only OAuth hosts get a real popup; any other window.open loads in place.
@MainActor
@Observable
private final class SignInPopupHost: NSObject, WKUIDelegate {
    var popupWebView: WKWebView?

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        guard NavigationPolicy.requiresPopupWindow(url) else {
            webView.load(navigationAction.request)
            return nil
        }
        DiagnosticLog.shared.log(category: "nav",
            "account deletion window.open popup \(NavigationTrace.redact(url))")
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.uiDelegate = self
        popupWebView = popup
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView === popupWebView {
            popupWebView = nil
        }
    }
}

private struct AccountDeletionWebView: UIViewRepresentable {
    let popups: SignInPopupHost

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = BrowserIdentity.userAgentSuffix
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = popups
        webView.load(URLRequest(url: URL(string: "https://privacy.patreon.com/policies")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}
