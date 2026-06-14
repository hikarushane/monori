import SwiftUI
import WebKit
import os

struct PatreonWebView: UIViewRepresentable {
    let model: WebViewModel
    /// Called when the user taps the page. The Bool is true when the tap landed
    /// in the central region (middle 50% horizontally, middle 40% vertically),
    /// which the reader uses to toggle its chrome without firing on link taps
    /// near the edges.
    var onContentTap: ((Bool) -> Void)? = nil
    /// When set, the left-edge swipe calls this instead of the default
    /// goBack() behavior. The reader uses it to leave the reader.
    var backSwipeOverride: (() -> Void)? = nil
    /// When set, the default left-edge swipe path only goes back if this
    /// returns true. Overrides still own their full behavior.
    var allowBackSwipe: (() -> Bool)? = nil

    private static let backSwipeName = "chapterly.backSwipe"
    private static let contentTapName = "chapterly.contentTap"

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView
        context.coordinator.onContentTap = onContentTap
        context.coordinator.backSwipeOverride = backSwipeOverride
        context.coordinator.allowBackSwipe = allowBackSwipe
        // The web view is shared and outlives this representable; re-attach the
        // gestures to the current coordinator so closures never go stale.
        for gesture in webView.gestureRecognizers ?? []
        where gesture.name == Self.backSwipeName || gesture.name == Self.contentTapName {
            webView.removeGestureRecognizer(gesture)
        }
        let edge = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleBackSwipe(_:)))
        edge.edges = .left
        edge.name = Self.backSwipeName
        webView.addGestureRecognizer(edge)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleContentTap(_:)))
        tap.name = Self.contentTapName
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        webView.addGestureRecognizer(tap)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onContentTap = onContentTap
        context.coordinator.backSwipeOverride = backSwipeOverride
        context.coordinator.allowBackSwipe = allowBackSwipe
    }

    /// Patreon navigates client-side (same-document history entries), which
    /// WKWebView's built-in back gesture ignores even though goBack() handles
    /// them fine — so drive goBack() from our own left-edge swipe.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onContentTap: ((Bool) -> Void)?
        var backSwipeOverride: (() -> Void)?
        var allowBackSwipe: (() -> Bool)?

        private static let log = Logger(subsystem: "dev.chapterly",
                                        category: "smoke-diagnostics")

        @objc func handleBackSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended,
                  let webView = gesture.view as? WKWebView else { return }
            let dx = gesture.translation(in: webView).x
            #if DEBUG
            // Paths only — never query strings or full URLs with parameters.
            let backPaths = webView.backForwardList.backList.suffix(5)
                .map { $0.url.path }.joined(separator: " <- ")
            Self.log.notice("[SMOKE] back_swipe dx=\(Int(dx)) canGoBack=\(webView.canGoBack) current=\(webView.url?.path ?? "nil", privacy: .public) back5=[\(backPaths, privacy: .public)]")
            #endif
            guard dx > 60 else { return }
            if let backSwipeOverride {
                backSwipeOverride()
            } else if webView.canGoBack {
                if let allowBackSwipe, !allowBackSwipe() {
                    #if DEBUG
                    Self.log.notice("[SMOKE] back_swipe action=noop reason=blocked_at_root")
                    #endif
                    return
                }
                animateBackTransition(on: webView)
                #if DEBUG
                Self.log.notice("[SMOKE] back_swipe action=goBack target=\(webView.backForwardList.backItem?.url.path ?? "nil", privacy: .public)")
                #endif
                webView.goBack()
            } else {
                #if DEBUG
                Self.log.notice("[SMOKE] back_swipe action=noop reason=canGoBack_false")
                #endif
            }
        }

        /// goBack() swaps content in place with no transition. Slide a snapshot
        /// of the outgoing page to the right so back-navigation reads as "pop",
        /// like a native navigation stack. The snapshot is transient and
        /// released when the animation completes.
        private func animateBackTransition(on webView: WKWebView) {
            guard let snapshot = webView.snapshotView(afterScreenUpdates: false) else { return }
            snapshot.frame = webView.bounds
            webView.addSubview(snapshot)
            UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut]) {
                snapshot.frame.origin.x = webView.bounds.width
            } completion: { _ in
                snapshot.removeFromSuperview()
            }
        }

        @objc func handleContentTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let view = gesture.view,
                  let onContentTap else { return }
            let point = gesture.location(in: view)
            let bounds = view.bounds
            let isCenter = point.x > bounds.width * 0.25 && point.x < bounds.width * 0.75
                && point.y > bounds.height * 0.30 && point.y < bounds.height * 0.70
            onContentTap(isCenter)
        }

        // The web view must keep receiving the same touches (links, scrolling).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
