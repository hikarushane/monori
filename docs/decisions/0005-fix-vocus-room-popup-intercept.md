# ADR-0005: Intercept Vocus Room URLs Instead of Creating Popup WebView

## Status
Superseded by ADR-0007

> **Correction (2026-07-03):** the root-cause attribution below ("Vocus changed their SPA") is wrong. Room links had loaded in the main WebView since a12eba5 (2026-06-12); what changed was our own popup handling in 784bd9d (2026-06-30), which routed every allowed `window.open` URL into a bare popup sheet. The per-URL interception this ADR chose was replaced by an OAuth-only popup policy in ADR-0007 after Google Docs hit the same regression.

## Date
2026-06-30

## Context
Vocus changed their SPA to open room (collection) pages via `window.open()` / `target="_blank"` instead of in-page navigation. This triggers `WKUIDelegate.createWebViewWith`, which creates a bare popup `WKWebView` presented as a SwiftUI `.sheet`.

The popup WKWebView has none of the infrastructure the main WebView has:
- No injected user scripts (`VocusRoomDetect.js`)
- No `WKScriptMessageHandler` registrations (`monoriCollectionLink`)
- No KVO URL observation feeding `WebCollectionBanner`

Result: the "Import chapters" button never appears on room pages. The room content renders correctly in the popup, but Monori cannot detect it as a collection.

Requirements:
- Restore import button functionality for Vocus room pages
- Keep popup support for all other `window.open` / `target="_blank"` uses (Patreon, Google OAuth, external links)
- Minimal change — no new files, no architecture refactor
- Preserve existing detection pipeline (`VocusRoomDetect.js` → `monoriCollectionLink` → `WebCollectionBanner`)

## Decision
Intercept Vocus room URLs in `WebViewModel.createWebViewWith`. When `URLNormalizer.isVocusRoomURL` matches the requested URL, load it in the main WebView (`webView.load(URLRequest(url: url))`) and return `nil` (no popup created). All other URLs continue through the existing popup path.

```swift
case .allowInWebView:
    if URLNormalizer.isVocusRoomURL(url.absoluteString) {
        webView.load(URLRequest(url: url))
        return nil
    }
    let popup = WKWebView(frame: .zero, configuration: configuration)
    popup.uiDelegate = self
    popupWebView = popup
    return popup
```

## Alternatives Considered

### Method B: Inject Scripts and Handlers into Popup WebView
- Pros: Preserves Vocus's intended popup behavior; popup WKWebView would gain full detection capability
- Cons: Requires duplicating script injection (`WKUserScript` setup), registering message handlers on the popup's `userContentController`, adding KVO observation on the popup's URL, and making `WebCollectionBanner` observe the popup model — touching 3-4 files with ~40 lines of new code
- Rejected: High surface area for a problem caused by one site's SPA change. Popup WKWebView lifecycle is harder to manage (who owns the observation? when is it torn down?). The popup `.sheet` also hides Monori's source picker and tab bar, which is poor UX for a page the user wants to import from.

### Do Nothing / Wait for Vocus to Revert
- Rejected: No indication Vocus will revert. Users cannot import room collections in the meantime.

## Consequences
- Room pages load as in-page navigation in the main WebView, which means the user loses the browser back button to return to the salon page. This is acceptable because the WebView already supports swipe-back gesture and the source picker provides alternate navigation.
- If Vocus adds other URL patterns that use `window.open` for non-room content, those will still create popups correctly (the check is specific to `isVocusRoomURL`).
- If Vocus changes their room URL structure, `URLNormalizer.isVocusRoomURL` would need updating — but that function is already the single source of truth for room URL detection throughout the app.
- The fix is 3 lines in one file with no new dependencies. Easy to revert if Vocus changes behavior again.
