# ADR-0008: Identify as Safari in the WebView User-Agent

## Status
Accepted

## Date
2026-08-12

## Context
A beta tester on iPhone 15 / iOS 26.6 reported that Patreon's "Continue with Google" button rendered greyed out and did nothing. Their account is Google-linked, so after entering their email Patreon answered "Log in with your Google account." — leaving them with no way in.

Reproduced on a clean simulator install, then traced with a temporary DEBUG user script that reported `window.open` calls, JS errors and failed subresources:

```text
[OAUTHDIAG] resource url=https://accounts.google.com/gsi/client msg=SCRIPT
```

Google Identity Services — the SDK Patreon's Google button is built on — never loaded. The same URL, fetched with each User-Agent and nothing else changed:

| User-Agent | Result |
|---|---|
| WKWebView default (`… Mobile/15E148`) | **403**, 1.6 KB error page |
| Same plus `Version/18.7 … Safari/604.1` | **200**, 266 KB SDK |

WKWebView's stock UA carries neither a `Version/` nor a `Safari/` token. Google reads that as an embedded web view and refuses to serve the SDK. Without it Patreon renders an inert fallback button — the greyed button in the report.

Two findings ruled out the obvious alternatives: Apple sign-in opened its popup correctly on the same build, so the `window.open` path (ADR-0007) was healthy; and the Google button never called `window.open` at all, so nothing was being dropped in transit.

Confirmed by a single-variable experiment: with the two tokens appended, `gsi/client` loaded, Google's own button iframe (`accounts.google.com/gsi/button`) appeared, Patreon served its normal login layout, and tapping the button opened the real Google OAuth page with no `disallowed_useragent` interstitial.

## Decision
`WebViewModel` sets `WKWebViewConfiguration.applicationNameForUserAgent` to `BrowserIdentity.userAgentSuffix` (`"Version/18.7 Safari/604.1"`), so every Monori web view identifies as Safari.

`applicationNameForUserAgent` rather than `customUserAgent`: the base UA keeps tracking WebKit, and only the suffix is ours to maintain. `BrowserIdentityTests` fails if either token is dropped, because losing one silently kills the Google button again.

The same investigation surfaced a second, unrelated defect: `m.facebook.com` was in neither `NavigationPolicy.decide`'s allowlist nor `requiresPopupWindow`, so Patreon's Facebook login was ejected to Safari and could never post back to its opener. Both lists now carry the Facebook hosts, covered by `NavigationPolicyFacebookTests` — the exact failure ADR-0007's consequences predicted for the next OAuth provider.

## Alternatives Considered

### Keep the stock UA, guide the user instead
Detect the Google-SSO dead end and tell the user to set a Patreon password in Safari first, or use another provider.
- Pros: leaves Google's embedded-webview check untouched
- Cons: every Google-account patron pays a multi-step detour through another browser before they can use the app at all
- Rejected by the project owner on 2026-08-12 in favour of the UA change, with the trade-off below understood

### Route OAuth through `ASWebAuthenticationSession`
- Rejected: it authenticates against a custom callback scheme and cannot deposit Patreon's session cookies into our `WKWebView`, which is what every downstream feature reads

## Consequences
- Google, Apple and Facebook sign-in all complete inside the app.
- Patreon serves its full desktop-grade login layout to us now, so login-page selectors may differ from what the stock UA saw. Anything that keys off that page needs re-checking against the new markup.
- **Accepted risk:** Google's embedded-webview check is anti-phishing protection aimed at apps that inject JS into the pages they host, which Monori does (reader CSS, collection detection). Presenting as Safari defeats that check. Google can add signals beyond the UA at any time and break Google sign-in again without notice; the failure would look exactly like this report. Treat a recurrence as expected, not as a regression to patch by escalating the spoof.
- `Version/18.7` tracks the OS token WebKit itself reports (`iPhone OS 18_7`), not the device's iOS release. Move both together if WebKit unfreezes its value.
- Verified on simulator 2026-08-12: `gsi/client` loads, Google's OAuth page opens in the popup sheet, Facebook's OAuth dialog stays in the app. No real sign-in was performed — completing a Patreon login stays a manual user step.
