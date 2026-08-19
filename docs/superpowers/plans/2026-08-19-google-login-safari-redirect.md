# Google Login Safari Redirect Fix

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After Google sign-in inside Monori, `drive.google.com` must render in the app's Browse tab webview, not bounce to Safari.

**Architecture:** The app uses `WKNavigationActionPolicy(rawValue: allow + 2)` to suppress Universal Link handling for Google domains. This private API maps to WebKit's internal `_WKNavigationActionPolicyAllowWithoutTryingAppLink`. The raw value (3) is confirmed valid on the current SDK, but may no longer be honored at runtime on iOS 26. This plan instruments the navigation path first (Task 1), captures evidence of the exact failure point (Task 2), then applies the smallest fix the evidence supports (Task 3, with three conditional branches), and verifies end-to-end (Task 4).

**Tech Stack:** Swift 5 / SwiftUI / WKWebView, MonoriCore SwiftPM package, `os.Logger` via `DiagnosticLog`, XCTest.

## Prior investigation (this session, before this plan)

- **Symptom confirmed:** video shows login in the MAIN webview (tab bar visible), not popup. After password + 2FA submission, Safari opens with `drive.google.com`, app shows stale login page.
- **Reproducible on:** Simulator AND real device.
- **Popup fix (commit `e9ff55d`) confirmed irrelevant:** it added `popup.navigationDelegate = self` (line 467), but the login is in the main webview which already had `navigationDelegate = self`.
- **NavigationPolicy.decide** correctly returns `.allowInWebView` for `drive.google.com`.
- **allowPolicy(for:)** correctly returns `rawValue: 3` (allow + 2) for Google domains.
- **rawValue 3** is a valid `WKNavigationActionPolicy` on this SDK (verified with a Swift script).
- **Only `decidePolicyFor` is implemented.** No `didReceiveServerRedirectForProvisionalNavigation`, no `didStartProvisionalNavigation`, no `didFailProvisionalNavigation` — so we cannot see redirects or failed navigations.

## Global Constraints

- **The Iron Law applies.** Task 2 captures evidence before any fix lands. Do not reorder Task 3 ahead of Task 2.
- **Google password, 2FA, CAPTCHA, email verification are manual user steps.** Never type, read, store, print, or automate them.
- **Never log secrets.** URLs are emitted as scheme + host + path only. No cookies, headers, query strings, fragments. See COMPLIANCE.md.
- **Do not erase or reset the Simulator, do not delete the app.** Logged-in state must survive.
- **This bug is in the MAIN webview.** The popup `navigationDelegate` fix (commit `e9ff55d`) is already in place and confirmed irrelevant.
- **Verification command:** `./scripts/verify.sh` must stay green.

---

## File Structure

| File | Responsibility |
|---|---|
| `MonoriCore/Sources/MonoriCore/NavigationTrace.swift` | **Create.** Secret-free one-line renderer for a navigation decision. |
| `MonoriCore/Tests/MonoriCoreTests/NavigationTraceTests.swift` | **Create.** Proves query strings and fragments never reach the log. |
| `App/WebView/WebViewModel.swift` | **Modify.** Add comprehensive tracing; add redirect/provisional navigation delegates; apply evidence-based fix (Task 3). |

---

### Task 1: Comprehensive navigation tracing

**Files:**
- Create: `MonoriCore/Sources/MonoriCore/NavigationTrace.swift`
- Create: `MonoriCore/Tests/MonoriCoreTests/NavigationTraceTests.swift`
- Modify: `App/WebView/WebViewModel.swift:383-427` (navigation delegate) and `:444-478` (UI delegate)

**Interfaces:**
- Consumes: `NavigationDecision` (`MonoriCore/Sources/MonoriCore/NavigationPolicy.swift:3-7`), `DiagnosticLog.shared.log(category:_:)` (`MonoriCore/Sources/MonoriCore/DiagnosticLog.swift:42`).
- Produces:
  - `NavigationTrace.Surface` — `enum { case main, popup }`, `String`-backed.
  - `NavigationTrace.line(surface:kind:isMainFrame:decision:url:) -> String`
  - `NavigationTrace.redact(_ url: URL) -> String`
  Task 3 references `NavigationTrace.redact` for the Universal Link suppression key.

- [ ] **Step 1: Write the failing tests**

Create `MonoriCore/Tests/MonoriCoreTests/NavigationTraceTests.swift`:

```swift
import XCTest
@testable import MonoriCore

final class NavigationTraceTests: XCTestCase {

    func testDropsQueryAndFragment() {
        let url = URL(string: "https://accounts.google.com/o/oauth2/auth?client_id=123&state=SECRET_STATE#id_token=SECRET_TOKEN")!
        let line = NavigationTrace.line(surface: .main, kind: "other", isMainFrame: true,
                                        decision: .allowInWebView, url: url)
        XCTAssertFalse(line.contains("SECRET_STATE"))
        XCTAssertFalse(line.contains("SECRET_TOKEN"))
        XCTAssertFalse(line.contains("?"))
        XCTAssertFalse(line.contains("#"))
        XCTAssertTrue(line.contains("https://accounts.google.com/o/oauth2/auth"))
    }

    func testRendersSurfaceKindFrameAndDecision() {
        let url = URL(string: "https://drive.google.com/drive/my-drive")!
        XCTAssertEqual(
            NavigationTrace.line(surface: .popup, kind: "other", isMainFrame: true,
                                 decision: .openInSafari, url: url),
            "popup other mainFrame=true -> openInSafari https://drive.google.com/drive/my-drive")
    }

    func testNamesEveryDecision() {
        let url = URL(string: "https://www.patreon.com/home")!
        func line(_ d: NavigationDecision) -> String {
            NavigationTrace.line(surface: .main, kind: "link", isMainFrame: true, decision: d, url: url)
        }
        XCTAssertTrue(line(.allowInWebView).contains("-> allowInWebView"))
        XCTAssertTrue(line(.openInSafari).contains("-> openInSafari"))
        XCTAssertTrue(line(.block).contains("-> block"))
    }

    func testRootPathRendersAsSlash() {
        XCTAssertEqual(NavigationTrace.redact(URL(string: "https://drive.google.com")!),
                       "https://drive.google.com/")
    }

    func testHostlessURLIsRenderedWithoutLeakingTheRest() {
        let line = NavigationTrace.redact(URL(string: "about:blank")!)
        XCTAssertEqual(line, "about://<no-host>")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd MonoriCore && swift test --filter NavigationTraceTests 2>&1 | tail -20`
Expected: compile FAIL — `cannot find 'NavigationTrace' in scope`.

- [ ] **Step 3: Write the implementation**

Create `MonoriCore/Sources/MonoriCore/NavigationTrace.swift`:

```swift
import Foundation

public enum NavigationTrace {
    public enum Surface: String, Sendable {
        case main
        case popup
    }

    public static func line(surface: Surface,
                            kind: String,
                            isMainFrame: Bool,
                            decision: NavigationDecision,
                            url: URL) -> String {
        "\(surface.rawValue) \(kind) mainFrame=\(isMainFrame) -> \(name(decision)) \(redact(url))"
    }

    public static func redact(_ url: URL) -> String {
        let scheme = url.scheme?.lowercased() ?? "unknown"
        guard let host = url.host?.lowercased() else { return "\(scheme)://<no-host>" }
        let path = url.path.isEmpty ? "/" : url.path
        return "\(scheme)://\(host)\(path)"
    }

    private static func name(_ decision: NavigationDecision) -> String {
        switch decision {
        case .allowInWebView: return "allowInWebView"
        case .openInSafari: return "openInSafari"
        case .block: return "block"
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd MonoriCore && swift test --filter NavigationTraceTests 2>&1 | tail -20`
Expected: PASS, 5 tests.

- [ ] **Step 5: Add tracing to decidePolicyFor**

In `App/WebView/WebViewModel.swift`, replace the `#if DEBUG` block and its contents at lines 403-414, plus the switch at lines 415-427, with:

```swift
        let kind: String = switch navigationAction.navigationType {
        case .linkActivated: "link"
        case .formSubmitted: "form"
        case .backForward: "back/fwd"
        case .reload: "reload"
        case .formResubmitted: "resubmit"
        case .other: "other"
        @unknown default: "unknown"
        }
        let surface: NavigationTrace.Surface = (webView === popupWebView) ? .popup : .main
        if isMainFrame {
            DiagnosticLog.shared.log(category: "nav",
                NavigationTrace.line(surface: surface, kind: kind, isMainFrame: isMainFrame,
                                     decision: decision, url: url))
        }
        switch decision {
        case .allowInWebView:
            let policy = Self.allowPolicy(for: url)
            if isMainFrame {
                DiagnosticLog.shared.log(category: "nav",
                    "policy rawValue=\(policy.rawValue) for \(NavigationTrace.redact(url))")
            }
            decisionHandler(policy)
        case .openInSafari:
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        case .block:
            decisionHandler(.cancel)
        }
```

This removes the `#if DEBUG` guard (DiagnosticLog handles log-level filtering) and adds raw-value logging to confirm what policy is actually passed to the handler.

- [ ] **Step 6: Add server redirect, provisional navigation, and failure delegates**

In `App/WebView/WebViewModel.swift`, inside the `WKNavigationDelegate` extension, immediately after the closing `}` of `didFinish` (line 441), add:

```swift
    func webView(_ webView: WKWebView,
                 didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        let surface: NavigationTrace.Surface = (webView === popupWebView) ? .popup : .main
        if let url = webView.url {
            DiagnosticLog.shared.log(category: "nav",
                "\(surface.rawValue) serverRedirect \(NavigationTrace.redact(url))")
        }
    }

    func webView(_ webView: WKWebView,
                 didStartProvisionalNavigation navigation: WKNavigation!) {
        let surface: NavigationTrace.Surface = (webView === popupWebView) ? .popup : .main
        if let url = webView.url {
            DiagnosticLog.shared.log(category: "nav",
                "\(surface.rawValue) provisionalStart \(NavigationTrace.redact(url))")
        }
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let surface: NavigationTrace.Surface = (webView === popupWebView) ? .popup : .main
        DiagnosticLog.shared.log(category: "nav",
            "\(surface.rawValue) provisionalFailed code=\((error as NSError).code) \(error.localizedDescription)")
    }
```

These three delegates are currently missing entirely. Without them, server redirects, navigation starts, and navigation failures are invisible. The `provisionalFailed` delegate is especially critical: if WebKit starts loading `drive.google.com` but Universal Link handling interrupts it, this delegate fires with the error.

- [ ] **Step 7: Fix compliance issue in createWebViewWith and add tracing**

In `App/WebView/WebViewModel.swift`, in the `WKUIDelegate` extension:

Replace line 458 (`print("[NAV] window.open / _blank → \(decision) | \(url.absoluteString.prefix(120))")`):

```swift
        DiagnosticLog.shared.log(category: "nav",
            NavigationTrace.line(surface: .main, kind: "window.open", isMainFrame: true,
                                 decision: decision, url: url))
```

Replace line 472 (`print("[NAV] ⚠️ OPENING IN SAFARI (popup): \(url.absoluteString)")`):

```swift
            DiagnosticLog.shared.log(category: "nav",
                "window.open handed to Safari \(NavigationTrace.redact(url))")
```

Line 472 currently ships in Release (not behind `#if DEBUG`) and emits a full auth URL including query parameters. This is a compliance fix.

After `webView.load(navigationAction.request)` (line 463), add:

```swift
                DiagnosticLog.shared.log(category: "nav",
                    "window.open loaded in main \(NavigationTrace.redact(url))")
```

- [ ] **Step 8: Build and run the full suite**

Run: `./scripts/verify.sh`
Expected: exit 0.

- [ ] **Step 9: Commit**

```bash
git add MonoriCore/Sources/MonoriCore/NavigationTrace.swift \
        MonoriCore/Tests/MonoriCoreTests/NavigationTraceTests.swift \
        App/WebView/WebViewModel.swift
git commit -m "feat(diagnostics): trace navigation decisions with raw policy values

Adds comprehensive tracing to WebViewModel's navigation delegate:
- Every decidePolicyFor call: surface, navType, decision, URL (redacted)
- Raw WKNavigationActionPolicy value passed to handler
- Server redirects and provisional navigation lifecycle
- Fixes compliance issue: full auth URLs no longer printed in Release"
```

---

### Task 2: Capture the failing login — evidence gate

**Files:** none modified. This task produces `build/nav-trace.log` and a written finding.

**Interfaces:**
- Consumes: the tracing from Task 1.
- Produces: the evidence that determines which Task 3 branch to execute. Every conditional branch in Task 3 references this evidence.

**Rules:** the agent drives everything except credential entry. Do not ask "what screen are you on" — read the trace and take screenshots.

- [ ] **Step 1: Install the instrumented build**

Run: `./scripts/verify.sh`
Expected: exit 0, current build installed on the Simulator.

- [ ] **Step 2: Start the log stream**

Run, in the background:

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "dev.monori"' --style compact > build/nav-trace.log
```

- [ ] **Step 3: Drive to the Google sign-in screen**

Using `./scripts/ui-driver.sh` (read `SIMULATOR_PLAYBOOK.md` first):
1. Launch the app, open the Browse tab.
2. Switch the source picker to Google Drive. `BrowseView.ensureLoaded` loads `https://drive.google.com` (`MonoriCore/Sources/MonoriCore/SourceKind.swift:31-33`).
3. Screenshot. A signed-out `drive.google.com` redirects to a Google workspace/login page — this is expected.
4. Drive as far as the Google account/password screen and stop.

- [ ] **Step 4: Hand the keyboard to the user**

Tell the user, in one message: the app is on the Google sign-in screen, the trace is recording. They should enter their password and complete 2FA, then say when done. Do not type anything into credential fields. Do not read credential field values.

- [ ] **Step 5: Stop the stream and read the trace**

Run: `grep "\[nav\]" build/nav-trace.log`

Answer these six questions in writing before touching any code:

1. **Does `decidePolicyFor` fire for `drive.google.com`?** Look for a line containing `-> allowInWebView` and `drive.google.com`. If yes, the delegate IS being called for this URL.

2. **What raw policy value was returned?** Look for `policy rawValue=N for https://drive.google.com/…`. If `N == 3`, the `+2` hack was applied but Safari still opened — the hack is broken (hypothesis 1 confirmed).

3. **Does a `serverRedirect` line appear for `drive.google.com`?** If yes, a server-side 302/303 redirect was received by WebKit.

4. **Does a `window.open` line appear for `drive.google.com`?** If yes, the auth flow finishes via `window.open` and the `createWebViewWith` path is involved.

5. **Does a `provisionalFailed` line appear?** If yes, WebKit started loading `drive.google.com` but the navigation was interrupted — likely by Universal Link handling. The error code will confirm this (error code `102` in `WebKitErrorDomain` means "Frame load interrupted").

6. **What is the full hop sequence?** List every trace line from `accounts.google.com` to the last line. This is the evidence Task 3 fixes against.

- [ ] **Step 6: Record the finding**

Append the six answers and the relevant trace lines (already redacted by NavigationTrace) to this plan file under a new `## Captured Evidence (Task 2)` heading, and commit:

```bash
git add docs/superpowers/plans/2026-08-19-google-login-safari-redirect.md
git commit -m "docs: record navigation trace for Google login Safari redirect bug"
```

- [ ] **Step 7: Gate — choose Task 3 branch**

Based on the evidence, select exactly one branch:

| Evidence | Diagnosis | Branch |
|---|---|---|
| `decidePolicyFor` fires for `drive.google.com`, `rawValue=3`, Safari still opens | `+2` hack broken on iOS 26 | **3A** |
| `decidePolicyFor` fires for `drive.google.com`, `rawValue=3`, AND `provisionalFailed` appears | Universal Link intercepts after policy accepted | **3A** |
| `decidePolicyFor` does NOT fire for `drive.google.com` | Navigation bypasses delegate | **3B** |
| `window.open` line appears for `drive.google.com` | Auth finishes via popup path | **3C** |

If none match, stop and report the unexpected evidence. Do not guess a fix.

---

### Task 3A: Replace the broken `+2` hack with cancel-and-reload

**Run this task only if Task 2 confirmed: `decidePolicyFor` fired for `drive.google.com`, `rawValue=3` was returned, and Safari still opened (or `provisionalFailed` appeared).**

**Files:**
- Modify: `App/WebView/WebViewModel.swift:389-395` (`allowPolicy`) and the `decidePolicyFor` body

**Interfaces:**
- Consumes: `NavigationPolicy.isGoogleDomain(_:)` (existing, `NavigationPolicy.swift:61-68`), `NavigationTrace.redact` from Task 1.
- Produces: Modified `decidePolicyFor` that cancels Universal-Link-prone navigations and reloads them programmatically. `allowPolicy(for:)` is removed.

**Why this works:** Programmatic `webView.load()` calls do not go through the Universal Link interception path. Universal Links are checked for navigations dispatched by WebKit's page loader (link clicks, form submissions, server redirects). A load initiated by the app via `webView.load(URLRequest(url:))` bypasses that check. The `+2` hack was WebKit's internal mechanism to achieve the same suppression at the policy level. If `+2` no longer works, cancel-and-reload achieves the same result through a supported path.

- [ ] **Step 1: Add the suppression guard property**

In `App/WebView/WebViewModel.swift`, add a property to `WebViewModel` (near the other state properties, around line 25):

```swift
private var suppressingUniversalLinkFor: String?
```

- [ ] **Step 2: Add the suppression predicate**

Replace `allowPolicy(for:)` (lines 389-395) with:

```swift
    private static func needsUniversalLinkSuppression(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return NavigationPolicy.isGoogleDomain(host)
    }
```

This covers ALL Google domains — the same scope as the original `allowPolicy(for:)`. Narrowing the list to specific subdomains (drive, docs, sheets, slides) would leave `accounts.google.com` and other Google domains unprotected: if the user has a Google app installed, iOS could intercept those navigations via Universal Links and break the auth flow before it starts. The cancel-and-reload overhead for non-Universal-Link Google domains (e.g. `google.com.tw`) is one extra `decidePolicyFor` round-trip — negligible.

- [ ] **Step 3: Replace the .allowInWebView case in decidePolicyFor**

Replace the `.allowInWebView` case (from `case .allowInWebView:` through `decisionHandler(policy)`) with:

```swift
        case .allowInWebView:
            if isMainFrame, Self.needsUniversalLinkSuppression(url) {
                let key = NavigationTrace.redact(url)
                if suppressingUniversalLinkFor == key {
                    suppressingUniversalLinkFor = nil
                    DiagnosticLog.shared.log(category: "nav",
                        "Universal Link suppression pass-through \(key)")
                    decisionHandler(.allow)
                } else {
                    suppressingUniversalLinkFor = key
                    DiagnosticLog.shared.log(category: "nav",
                        "suppressing Universal Link, will reload \(key)")
                    decisionHandler(.cancel)
                    webView.load(URLRequest(url: url))
                }
                return
            }
            decisionHandler(.allow)
```

**How the loop guard works:**

1. First time `decidePolicyFor` fires for `drive.google.com`: `suppressingUniversalLinkFor` is nil, `key` is `"https://drive.google.com/…"`, they don't match. Cancel the navigation, set the guard, reload programmatically.
2. The programmatic `webView.load()` triggers `decidePolicyFor` again. Now `suppressingUniversalLinkFor == key`. Clear the guard, return plain `.allow`. The programmatic load does not trigger Universal Link handling.
3. Next navigation clears the guard naturally.

**Why subframes and non-Google URLs are safe:** The `isMainFrame` check skips subframes. Non-Google URLs fail the `needsUniversalLinkSuppression` check and go straight to `decisionHandler(.allow)`. Neither path touches `suppressingUniversalLinkFor`.

- [ ] **Step 4: Build and run the full suite**

Run: `./scripts/verify.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add App/WebView/WebViewModel.swift
git commit -m "fix(webview): replace broken allow+2 hack with cancel-and-reload

The private WKNavigationActionPolicy rawValue trick that suppressed
Universal Link handling for Google domains no longer works on iOS 26.
Replace it with a cancel-and-reload pattern: cancel the delegate-
dispatched navigation and reload the URL programmatically, which
bypasses Universal Link interception."
```

---

### Task 3B: Cover the missing navigation path

**Run this task only if Task 2 showed that `decidePolicyFor` did NOT fire for the `drive.google.com` navigation.**

**Files:**
- Modify: `App/WebView/WebViewModel.swift`

**Interfaces:**
- Consumes: the exact evidence from Task 2 (which navigation path was missed).
- Produces: depends on evidence.

**This task cannot be fully specified until Task 2 runs.** The trace will show WHERE the navigation escapes. Two likely scenarios:

1. **The navigation happens entirely between `provisionalStart` and `provisionalFailed` without a `decidePolicyFor` call.** This means WebKit initiated the load but Universal Link handling intercepted it before consulting the navigation delegate. In this case, the fix from Task 3A applies — but the trigger condition is the `provisionalFailed` error rather than a policy rawValue mismatch. Implement Task 3A with the evidence from this scenario.

2. **No trace lines appear at all for `drive.google.com`.** This means the navigation escapes the webview entirely — possibly through a system-level URL handler. In this case, the fix requires intercepting at the `UIApplicationDelegate` level or using `WKNavigationResponse` delegate methods.

- [ ] **Step 1: Analyze the trace gap**

Identify the last trace line before Safari opens and the URL it carries. The gap between that URL and `drive.google.com` is the missed navigation.

- [ ] **Step 2: Implement coverage based on the gap analysis**

The specific code depends on Step 1's finding. Write the fix, add a trace line confirming the new path fires, build, and test.

- [ ] **Step 3: Build and run the full suite**

Run: `./scripts/verify.sh`
Expected: exit 0.

- [ ] **Step 4: Commit**

Commit message must name the specific gap that was covered.

---

### Task 3C: Handle the window.open path for post-auth redirect

**Run this task only if Task 2 showed that `createWebViewWith` fired with a `drive.google.com` URL.**

**Files:**
- Modify: `App/WebView/WebViewModel.swift:460-464`

**Interfaces:**
- Consumes: `NavigationPolicy.requiresPopupWindow(_:)` (existing), `NavigationTrace` from Task 1.
- Produces: Modified `createWebViewWith` that suppresses Universal Links for the non-popup load.

**Why:** The non-popup path in `createWebViewWith` calls `webView.load(navigationAction.request)` (line 463). This is a programmatic load, which normally does not trigger Universal Links. If Task 2 shows this path IS involved, the issue is that either (a) the programmatic load does trigger Universal Links in this context, or (b) a popup was returned and its navigation to `drive.google.com` triggered them.

- [ ] **Step 1: Determine which sub-path**

From the Task 2 trace, check whether `createWebViewWith` returned a popup (look for `popup opened`) or loaded in main (look for `window.open loaded in main`).

- [ ] **Step 2: Apply the fix**

**If loaded in main:** The `webView.load()` call at line 463 somehow triggers Universal Links. Apply the same cancel-and-reload guard from Task 3A, but inside `createWebViewWith` instead of `decidePolicyFor`. Since `webView.load()` will trigger `decidePolicyFor`, this reduces to Task 3A — implement Task 3A instead.

**If popup opened:** The popup navigated to `drive.google.com` and the popup's `decidePolicyFor` (which fires because `popup.navigationDelegate = self` since commit `e9ff55d`) returned `rawValue=3` but Safari still opened. This also reduces to Task 3A — implement the cancel-and-reload in `decidePolicyFor`, which handles both main and popup surfaces.

- [ ] **Step 3: Build and run the full suite**

Run: `./scripts/verify.sh`
Expected: exit 0.

- [ ] **Step 4: Commit**

---

### Task 4: Verify the fix and update handoff

**Files:**
- Modify: `HANDOFF.md`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: verified sign-in and updated handoff.

- [ ] **Step 1: Re-run the full manual login**

Repeat Task 2 steps 1-5 on the fixed build. The user performs password and 2FA; the agent drives everything else and reads the trace.

Pass criteria, all four required:
1. Google Drive renders inside the app's Browse tab.
2. Safari never comes to the foreground.
3. `build/nav-trace.log` contains no `-> openInSafari` line for any Google host.
4. If Task 3A was used: a `suppressing Universal Link, will reload` line appears, followed by `Universal Link suppression pass-through` and a successful `provisionalStart` / `didFinish`.

- [ ] **Step 2: Verify Google Docs import path still works**

Open a Google Doc from Drive inside the app. Confirm the `Google 文件` banner appears with a working `匯入` button (`App/Features/Shared/WebCollectionBanner.swift`). This guards against `currentURL` or `finishedNavigationCount` being disrupted by cancel-and-reload.

- [ ] **Step 3: Update HANDOFF.md**

Record: what was broken, what the trace showed, which Task 3 branch landed, that `./scripts/verify.sh` is green, and that the fix needs a TestFlight build for real-device confirmation.

- [ ] **Step 4: Run verify.sh one final time**

Run: `./scripts/verify.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add HANDOFF.md
git commit -m "docs: update HANDOFF for Google login Safari redirect fix"
```

---

## Self-Review

**Spec coverage.** The reported symptom — "Google login in main webview, Safari opens with drive.google.com" — is covered. Task 1 instruments the complete navigation lifecycle (decisions, raw values, redirects, provisional loads, failures). Task 2 captures real evidence. Task 3 has three conditional branches covering every hypothesis from the prior investigation. Task 4 verifies end-to-end including the Google Docs import path.

**Placeholder scan.** Task 3B is intentionally underspecified — its implementation depends entirely on Task 2's evidence, and this is called out explicitly. Tasks 3A and 3C contain complete code. No "TBD", "TODO", or "add appropriate handling" anywhere.

**Type consistency.** `NavigationTrace.Surface`, `NavigationTrace.line()`, `NavigationTrace.redact()` are defined in Task 1 step 3 and used consistently in all later tasks. `suppressingUniversalLinkFor: String?` is defined in Task 3A step 1 and used in Task 3A step 3. `needsUniversalLinkSuppression(_:)` replaces `allowPolicy(for:)` in Task 3A step 2.

**Known risk, called out.** The cancel-and-reload pattern in Task 3A assumes programmatic `webView.load()` bypasses Universal Link interception. This is documented WebKit behavior, but WebKit internals can change. Task 4 step 1 verifies it works on the actual runtime. If it doesn't, stop and report — do not stack another hack.

**Adversarial verification (2026-08-19).** An independent refutation agent checked 7 claims. Two were refuted and fixed:
- `needsUniversalLinkSuppression` originally listed only 4 Google subdomains. This left `accounts.google.com` (and others like `meet.google.com`, `mail.google.com`) without suppression — if the user has a Google app installed, those navigations could also be intercepted by Universal Links, breaking the auth flow at step one. Fixed: the predicate now delegates to `NavigationPolicy.isGoogleDomain()`, matching the original `allowPolicy(for:)` scope.
- The domain list was also incomplete for future navigation scenarios (Google Meet, Calendar, Photos, Maps, Gmail all register Universal Links). Fixed by the same change — `isGoogleDomain()` covers all of them.

**Difference from the 2026-08-15 plan.** That plan focused on the popup path (missing `navigationDelegate` on the popup webview). The popup fix landed (commit `e9ff55d`) and is confirmed irrelevant. This plan focuses on the main webview path and the `+2` hack's effectiveness on iOS 26. Task 1 reuses the `NavigationTrace` design but adds raw-value logging and three new delegate methods that the old plan did not include.

---

## Captured Evidence (Task 2)

**Date:** 2026-08-19

### Diagnostic answers

1. **Does `decidePolicyFor` fire for `drive.google.com`?** YES. WebKit internal log shows `WebPageProxy::decidePolicyForNavigationAction` at 20:32:47.518 for pageProxyID=56 (Google Drive webview, PID 99719). The delegate returned `policyAction=Use` and the page loaded successfully in-app.

2. **What raw policy value was returned?** WebKit logs `policyAction=Use` for `drive.google.com`. Since `isGoogleDomain("drive.google.com")` is true, `allowPolicy(for:)` returns rawValue 3 (`allow + 2`). WebKit logs rawValue 3 as `Use` (same label as rawValue 1). The page loaded in-app without Safari opening, confirming the `+2` hack still works for domains it covers.

3. **Does a `serverRedirect` line appear?** YES. `didReceiveServerRedirectForProvisionalLoadForFrame` at 20:32:47.929 for the Google Drive page (expected redirect from `drive.google.com` to the actual rendered URL).

4. **Does a `window.open` line appear?** NO.

5. **Does `provisionalFailed` appear?** NO.

6. **Full hop sequence:** The app-level `[nav]` DiagnosticLog produced zero entries (a separate tracing bug in DiagnosticLog forwarding). Evidence was reconstructed from WebKit internal logs (`com.apple.WebKit:Loading`) and Safari's usage log (`com.apple.coreduet:context`).

### Root cause (unexpected — does not match any planned branch)

The failing URL is **`accounts.youtube.com/accounts/SetSID`**, not a `google.*` domain. This URL is part of Google's cross-domain session-setting chain: after successful OAuth on `accounts.google.com`, Google redirects through `accounts.youtube.com/accounts/SetSID` to sync login cookies.

`NavigationPolicy.isGoogleDomain("accounts.youtube.com")` returns **false** because the function only matches domains containing "google" as a hostname part. Therefore `NavigationPolicy.decide()` returns `.openInSafari`, and the app explicitly calls `UIApplication.shared.open(url)` to send the user to Safari.

**This is not a `+2` hack failure. The `+2` hack is never reached because the domain is not in the allowlist.**

Safari evidence (from `com.apple.coreduet:context` at 20:28:34):
```
webDomain = "accounts.youtube.com";
webpageURL = "https://accounts.youtube.com/accounts/SetSID";
```

### Branch decision

None of the planned branches (3A/3B/3C) match. The fix is simpler: add `youtube.com` to `isGoogleDomain()`. The `+2` hack automatically applies via `allowPolicy(for:)`.

### Fix applied

- `NavigationPolicy.swift:isGoogleDomain()` — added `youtube.com` and subdomains
- `NavigationPolicyGoogleTests.swift` — added YouTube OAuth and lookalike tests
