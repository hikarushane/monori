import SwiftUI
import WebKit

struct PatreonWebView: UIViewRepresentable {
    let model: WebViewModel

    private static let backSwipeName = "chapterly.backSwipe"

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView
        if !(webView.gestureRecognizers ?? []).contains(where: { $0.name == Self.backSwipeName }) {
            let edge = UIScreenEdgePanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleBackSwipe(_:)))
            edge.edges = .left
            edge.name = Self.backSwipeName
            webView.addGestureRecognizer(edge)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Patreon navigates client-side (same-document history entries), which
    /// WKWebView's built-in back gesture ignores even though goBack() handles
    /// them fine — so drive goBack() from our own left-edge swipe.
    final class Coordinator: NSObject {
        @objc func handleBackSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended,
                  let webView = gesture.view as? WKWebView,
                  gesture.translation(in: webView).x > 60,
                  webView.canGoBack else { return }
            webView.goBack()
        }
    }
}
