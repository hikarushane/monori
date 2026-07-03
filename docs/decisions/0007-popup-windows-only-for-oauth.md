# ADR-0007: Popup Windows Only for OAuth Endpoints

## Status
Accepted — supersedes ADR-0005

## Date
2026-07-03

## Context
784bd9d (2026-06-30) made every allowed `window.open` / `target="_blank"` URL spawn a bare popup WKWebView presented as a `.sheet`. That was necessary for OAuth: Apple/Google sign-in popups use `response_mode=web_message` and postMessage back to `window.opener`, so loading them in place destroys the opener and the auth page refuses to render outside a popup.

But the popup WKWebView carries none of the main WebView's infrastructure — no detection user scripts, no `monoriCollectionLink` message handler, no URL observation feeding `WebCollectionBanner`. Any **content** link opened via `window.open` / `target="_blank"` therefore lost the import banner:

1. Vocus room links broke the same day — patched per-URL in 934baa7 with an `isVocusRoomURL` check.
2. Google Docs in Drive "Shared with me" broke next (reported 2026-07-03) — Drive opens docs with `target="_blank"`.

ADR-0005 attributed the Vocus breakage to "Vocus changed their SPA". That attribution was **wrong**: git archaeology shows room links loaded fine in the main WebView from a12eba5 (2026-06-12) until 784bd9d changed our own popup handling. The per-URL allowlist approach guaranteed a regression for every next source (AO3, AsianFanfics, Patreon) whose links use `window.open`.

## Decision
Invert the classification. The question is not "which content site is this?" but "does this URL need real popup-window semantics?" — and only OAuth sign-in endpoints do.

`NavigationPolicy.requiresPopupWindow(_:)` returns true only for exact hosts `appleid.apple.com` and `accounts.google.com`. In `createWebViewWith`, URLs passing `NavigationPolicy.decide` load in the main WebView unless `requiresPopupWindow` is true; only then is a popup WKWebView created. The `isVocusRoomURL` special case is removed (subsumed).

```swift
case .allowInWebView:
    guard NavigationPolicy.requiresPopupWindow(url) else {
        webView.load(navigationAction.request)
        return nil
    }
    let popup = WKWebView(frame: .zero, configuration: configuration)
    popup.uiDelegate = self
    popupWebView = popup
    return popup
```

Exact-host match only — lookalike or suffixed hosts (`appleid.apple.com.evil.example`) must not get popup treatment. Covered by `NavigationPolicyPopupTests`.

## Alternatives Considered

### Extend the per-URL content allowlist (add `isGoogleDocURL`, then the next one…)
- Pros: smallest diff at each incident
- Cons: whack-a-mole; every future source regresses first and gets patched after; the Google Docs case would also need the exact URL form Drive opens (`drive.google.com/file/…` vs `docs.google.com/document/…`), which the allowlist can silently miss
- Rejected: treats each symptom, never the cause

### Inject scripts and handlers into the popup WKWebView (ADR-0005's Method B)
- Rejected in ADR-0005 and still rejected: duplicates the detection pipeline across web views, popup lifecycle ownership is murky, and the popup sheet hides Monori's source picker and tab bar anyway

## Consequences
- Content links opened via `window.open` navigate the main WebView — same behavior the app shipped with from 2026-06-12 to 2026-06-30. The popup sheet no longer hides the import banner for any source.
- OAuth popups (the reason 784bd9d existed) are unchanged: the popup-creation branch is byte-identical, gated behind `requiresPopupWindow`.
- Adding a future OAuth provider (e.g. Facebook login) requires adding its auth host to **both** `NavigationPolicy.decide`'s allowlist and `requiresPopupWindow`. A host missing from the latter breaks that provider's popup login — the failure mode is visible (login form doesn't render) rather than silent.
- Verified on-device 2026-07-03: Google Doc from 與我共享 loads in the main WebView with the import banner; Vocus room 九樓的女人們 loads with the room banner. Vocus's drawer room link sometimes navigates as a plain link and sometimes via `window.open` (SPA hydration timing) — both paths now end in the main WebView.
- ADR-0005 is superseded; its root-cause attribution ("Vocus changed their SPA") is corrected by this record.
