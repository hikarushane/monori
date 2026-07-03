import SwiftUI
import WebKit
import os

struct PatreonWebView: UIViewRepresentable {
    let model: WebViewModel
    @Environment(\.colorScheme) private var colorScheme
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
    /// When true, attaches a UIRefreshControl to the scroll view so the user
    /// can pull down to reload. Only BrowseView enables this; ReaderView does
    /// not — pulling in the reader would discard partially-read content.
    var enablePullToRefresh: Bool = false
    /// Called continuously while the user overscrolls past a page boundary.
    /// `edge` is `.top` or `.bottom` (nil when the overscroll is released back
    /// inside bounds). `progress` is in 0…1 where 1 = activation threshold.
    var onOverscroll: ((Edge?, CGFloat) -> Void)? = nil
    /// Called once when the user releases after crossing the activation
    /// threshold (80 pt). The reader uses this to navigate to the adjacent chapter.
    var onChapterBoundary: ((Edge) -> Void)? = nil

    private static let backSwipeName = "monori.backSwipe"
    private static let contentTapName = "monori.contentTap"
    #if DEBUG
    private static let diagLog = Logger(subsystem: "dev.monori", category: "smoke-diagnostics")
    #endif

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.model = model
        context.coordinator.onContentTap = onContentTap
        context.coordinator.backSwipeOverride = backSwipeOverride
        context.coordinator.allowBackSwipe = allowBackSwipe
        context.coordinator.onOverscroll = onOverscroll
        context.coordinator.onChapterBoundary = onChapterBoundary
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
        edge.delegate = context.coordinator
        webView.addGestureRecognizer(edge)

        // Pull-to-refresh: only enabled in Browse, not in the Reader where
        // pulling down would discard the user's reading position.
        if enablePullToRefresh {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(context.coordinator,
                                     action: #selector(Coordinator.handleRefresh(_:)),
                                     for: .valueChanged)
            webView.scrollView.refreshControl = refreshControl
        }

        // Only the Reader uses center-tap-to-toggle-chrome. Attaching this
        // recognizer to the Browse/login web view is unnecessary and adds gesture
        // pressure to the WKWebView text-input session, so install it only when a
        // handler is set.
        if onContentTap != nil {
            let tap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleContentTap(_:)))
            tap.name = Self.contentTapName
            tap.cancelsTouchesInView = false
            tap.delegate = context.coordinator
            webView.addGestureRecognizer(tap)
        }
        context.coordinator.setupChapterSwipeDetection(webView)
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        #if DEBUG
        if AppEnvironment.isSmokeMode {
            Self.diagLog.notice("[DRAWER] native makeUIView bounds=\(NSCoder.string(for: webView.bounds), privacy: .public)")
        }
        #endif
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.model = model
        context.coordinator.onContentTap = onContentTap
        context.coordinator.backSwipeOverride = backSwipeOverride
        context.coordinator.allowBackSwipe = allowBackSwipe
        context.coordinator.onOverscroll = onOverscroll
        context.coordinator.onChapterBoundary = onChapterBoundary
        uiView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        #if DEBUG
        if AppEnvironment.isSmokeMode {
            Self.diagLog.notice("[DRAWER] native updateUIView bounds=\(NSCoder.string(for: uiView.bounds), privacy: .public)")
        }
        #endif
    }

    /// Patreon navigates client-side (same-document history entries), which
    /// WKWebView's built-in back gesture ignores even though goBack() handles
    /// them fine — so drive goBack() from our own left-edge swipe.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onContentTap: ((Bool) -> Void)?
        var backSwipeOverride: (() -> Void)?
        var allowBackSwipe: (() -> Bool)?
        var onOverscroll: ((Edge?, CGFloat) -> Void)?
        var onChapterBoundary: ((Edge) -> Void)?
        /// Retained so handleRefresh can call reload() and observe isLoading.
        var model: WebViewModel?
        private var refreshObservation: NSKeyValueObservation?

        // MARK: - Chapter swipe detection
        private var scrollObservation: NSKeyValueObservation?
        private var panObservation: NSKeyValueObservation?
        private var activeEdge: Edge?
        private var activatedThreshold = false
        private let activationThreshold: CGFloat = 80

        func setupChapterSwipeDetection(_ webView: WKWebView) {
            guard onOverscroll != nil else { return }
            let scrollView = webView.scrollView

            scrollObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                guard let self else { return }
                let y = sv.contentOffset.y
                let maxY = sv.contentSize.height - sv.frame.height

                if y < 0 {
                    let progress = min(1, -y / self.activationThreshold)
                    if progress >= 1.0, !self.activatedThreshold {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    self.activatedThreshold = progress >= 1.0
                    self.activeEdge = .top
                    self.onOverscroll?(.top, progress)
                } else if maxY > 0, y > maxY {
                    let excess = y - maxY
                    let progress = min(1, excess / self.activationThreshold)
                    if progress >= 1.0, !self.activatedThreshold {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    self.activatedThreshold = progress >= 1.0
                    self.activeEdge = .bottom
                    self.onOverscroll?(.bottom, progress)
                } else if self.activeEdge != nil {
                    self.activeEdge = nil
                    self.activatedThreshold = false
                    self.onOverscroll?(nil, 0)
                }
            }

            panObservation = scrollView.panGestureRecognizer.observe(\.state, options: [.new]) { [weak self] pan, _ in
                guard let self else { return }
                let ended = pan.state == .ended || pan.state == .cancelled || pan.state == .failed
                guard ended else { return }
                if self.activatedThreshold, let edge = self.activeEdge {
                    self.onChapterBoundary?(edge)
                }
                self.activeEdge = nil
                self.activatedThreshold = false
                self.onOverscroll?(nil, 0)
            }
        }

        private static let log = Logger(subsystem: "dev.monori",
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

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            guard let model else {
                sender.endRefreshing()
                return
            }
            model.webView.reload()
            refreshObservation = model.webView.observe(\.isLoading, options: [.new]) { [weak sender] _, change in
                if change.newValue == false {
                    DispatchQueue.main.async { sender?.endRefreshing() }
                }
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

        // Give the app-level left-edge gesture priority over horizontal web
        // content gestures such as collection carousels.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer.name == PatreonWebView.backSwipeName,
                  let edgeView = gestureRecognizer.view,
                  let otherView = otherGestureRecognizer.view else { return false }
            return otherView.isDescendant(of: edgeView)
        }
    }
}
