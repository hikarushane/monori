import Foundation

public enum BackSwipeAction: Equatable {
    /// Drive WKWebView.goBack().
    case goBack
    /// At the logical root (home feed): swallow the gesture so it can't surface
    /// an out-of-band page (e.g. a Cloudflare challenge held in history).
    case stayAtRoot
    /// No back history at all: nothing to do.
    case none
}

public enum BackSwipePolicy {
    public static func shouldDismissNavigation(
        startX: CGFloat,
        translationX: CGFloat,
        translationY: CGFloat,
        edgeWidth: CGFloat = 24,
        activationDistance: CGFloat = 60
    ) -> Bool {
        guard startX <= edgeWidth,
              translationX >= activationDistance else { return false }
        return abs(translationX) > abs(translationY)
    }

    /// Decide what a left-edge back-swipe should do on the Browse web view.
    /// Pure and UIKit-free so it is unit-testable; the view layer maps the
    /// result onto WKWebView. URL is inspected by path only.
    public static func browseDecision(currentURL: URL?, canGoBack: Bool) -> BackSwipeAction {
        guard canGoBack else { return .none }
        if let url = currentURL, URLNormalizer.isPatreonHome(url) { return .stayAtRoot }
        return .goBack
    }
}
