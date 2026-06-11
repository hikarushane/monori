# Smoke-Auto Automated Smoke Test Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One command, `./scripts/smoke-auto.sh`, that drives the full MVP flow (auth check → collection detect → import → reader → CSS → progress save/restore) on the logged-in simulator and exits 0 only when every step passes.

**Architecture:** A debug-only `SmokeAutopilot` step machine inside the app performs the same actions a user does by hand and logs each step as a machine-parseable `[SMOKE]` line; a driver script builds, launches two phases, parses the log, and maps results to exit codes 0/1/2/3.

**Tech Stack:** Swift/SwiftUI (iOS 17), WKWebView, os.Logger unified logging, SwiftData via existing `LibraryStore`, bash + `xcrun simctl`, XCTest for `ChapterlyCore` unit tests.

**Spec:** `docs/superpowers/specs/2026-06-10-smoke-auto-design.md`

**Existing context an implementer needs:**

- `AppEnvironment` (App/AppEnvironment.swift) owns `browse`/`reader` `WebViewModel`s and the `LibraryStore`. It already supports `--smoke-diagnostics` via `AppEnvironment.isSmokeMode` and logs `[SMOKE]` lines with `Logger(subsystem: "dev.chapterly", category: "smoke-diagnostics")`.
- `WebViewModel` (App/WebView/WebViewModel.swift) exposes `currentURL`, `isOnCollectionPage` (URL path contains `/collection/`), `load(_:)`, `runCollectionImport()`, and the underlying `webView`.
- Import path: `runCollectionImport()` → JS posts chapters → `AppEnvironment.wire` batches with a 300 ms debounce → `store.applyImport` → `importedCountThisSession` is set.
- Reader: `ReaderView` (App/Features/Reader/ReaderView.swift) loads the chapter URL into `env.reader`, injects `ReaderStyler.injectionScript()` (style element id = `ReaderStyler.styleElementID` = `"chapterly-reader-style"`), and restores scroll 0.6 s after load when `readingProgress` ∈ (0.02, 0.97).
- Progress save: bundled `ProgressTracker.js` posts `{url, scrollProgress}` on scroll (500 ms throttle) → `store.setProgress(forPageURL:progress:)`.
- `LocalChapterModel.id` is a `String` (`@Attribute(.unique) public var id: String`).
- `scripts/smoke-diagnostics.sh preflight-only` runs all preflight checks (XcodeGen, scheme, booted simulator) and exits non-zero on failure.
- Unit tests: XCTest in `ChapterlyCore/Tests/ChapterlyCoreTests/`, run with `swift test` from `ChapterlyCore/` (this is what `verify.sh` does).
- `.env` is gitignored and must never be read or printed by Claude; the script sources it locally. `.env.example` is committed.

---

### Task 1: `SmokeCheck` / `SmokeReport` helpers in ChapterlyCore (TDD)

Pure logic used by the autopilot: tolerance comparison and step-line formatting. Lives in core so it is unit-testable without the simulator.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/SmokeSupport.swift`
- Create: `ChapterlyCore/Tests/ChapterlyCoreTests/SmokeSupportTests.swift`

- [ ] **Step 1: Write the failing test**

Create `ChapterlyCore/Tests/ChapterlyCoreTests/SmokeSupportTests.swift`:

```swift
import XCTest
@testable import ChapterlyCore

final class SmokeSupportTests: XCTestCase {

    // MARK: SmokeCheck

    func testApproximatelyEqualWithinTolerance() {
        XCTAssertTrue(SmokeCheck.approximatelyEqual(0.5, 0.55, tolerance: 0.1))
        XCTAssertTrue(SmokeCheck.approximatelyEqual(0.55, 0.5, tolerance: 0.1))
        XCTAssertTrue(SmokeCheck.approximatelyEqual(0.5, 0.6, tolerance: 0.1))
    }

    func testApproximatelyEqualOutsideTolerance() {
        XCTAssertFalse(SmokeCheck.approximatelyEqual(0.5, 0.61, tolerance: 0.1))
        XCTAssertFalse(SmokeCheck.approximatelyEqual(0.2, 0.5, tolerance: 0.1))
    }

    // MARK: SmokeReport

    func testStepLinePass() {
        XCTAssertEqual(SmokeReport.stepLine(step: "import", pass: true, reason: nil),
                       "step=import result=pass")
    }

    func testStepLineFailWithReason() {
        XCTAssertEqual(SmokeReport.stepLine(step: "auth", pass: false, reason: "not_logged_in"),
                       "step=auth result=fail reason=not_logged_in")
    }

    func testStepLinePassIgnoresReason() {
        XCTAssertEqual(SmokeReport.stepLine(step: "import", pass: true, reason: "ignored"),
                       "step=import result=pass")
    }

    func testStepLineReasonWhitespaceIsSanitized() {
        XCTAssertEqual(SmokeReport.stepLine(step: "x", pass: false, reason: "two words"),
                       "step=x result=fail reason=two_words")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChapterlyCore && swift test --filter SmokeSupportTests`
Expected: compile FAILURE — `cannot find 'SmokeCheck' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `ChapterlyCore/Sources/ChapterlyCore/SmokeSupport.swift`:

```swift
import Foundation

/// Pure helpers for the debug-only smoke autopilot. Kept in ChapterlyCore so the
/// log-line format and tolerance logic are unit-testable without a simulator.
public enum SmokeCheck {
    public static func approximatelyEqual(_ a: Double, _ b: Double, tolerance: Double) -> Bool {
        abs(a - b) <= tolerance
    }
}

public enum SmokeReport {
    /// Machine-parseable step line: `step=<name> result=pass|fail [reason=<reason>]`.
    /// Reasons never contain spaces so the driver script can parse with a simple regex.
    public static func stepLine(step: String, pass: Bool, reason: String?) -> String {
        var line = "step=\(step) result=\(pass ? "pass" : "fail")"
        if !pass, let reason {
            line += " reason=\(reason.replacingOccurrences(of: " ", with: "_"))"
        }
        return line
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChapterlyCore && swift test --filter SmokeSupportTests`
Expected: `Executed 6 tests, with 0 failures`

- [ ] **Step 5: Run the full core suite to check for regressions**

Run: `cd ChapterlyCore && swift test`
Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add ChapterlyCore/Sources/ChapterlyCore/SmokeSupport.swift ChapterlyCore/Tests/ChapterlyCoreTests/SmokeSupportTests.swift
git commit -m "Add SmokeCheck and SmokeReport helpers for smoke autopilot"
```

---

### Task 2: Autopilot launch flags + reader presentation hook in `AppEnvironment`

**Files:**
- Modify: `App/AppEnvironment.swift`

- [ ] **Step 1: Add flags and autopilot storage**

In `App/AppEnvironment.swift`, directly below the existing `isSmokeMode` property (lines 18–20), add:

```swift
    static var isAutopilot: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-autopilot") || isAutopilotPhase2
    }

    static var isAutopilotPhase2: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-autopilot-phase2")
    }

    #if DEBUG
    var autopilotReaderTarget: AutopilotReaderTarget?
    private var autopilot: SmokeAutopilot?
    #endif
```

- [ ] **Step 2: Start the autopilot from `init`**

In the same file, inside `init()` after the existing smoke-mode block:

```swift
        if Self.isSmokeMode {
            printSmokeDiagnostics()
            startSmokeDiagnosticsTimer()
        }

        #if DEBUG
        if Self.isAutopilot {
            let autopilot = SmokeAutopilot(env: self)
            self.autopilot = autopilot
            autopilot.start()
        }
        #endif
```

- [ ] **Step 3: Commit (will not compile until Task 3 — commit together if preferred)**

Hold the commit; Task 3 creates `SmokeAutopilot` and `AutopilotReaderTarget`. Commit happens at the end of Task 3.

---

### Task 3: `SmokeAutopilot` step machine

**Files:**
- Create: `App/SmokeAutopilot.swift`

- [ ] **Step 1: Create the file with the full implementation**

Create `App/SmokeAutopilot.swift`:

```swift
#if DEBUG
import Foundation
import WebKit
import ChapterlyCore
import os

struct AutopilotReaderTarget: Identifiable {
    let id: String
    let chapter: LocalChapterModel
}

/// Debug-only smoke autopilot. Activated by the `--smoke-autopilot` /
/// `--smoke-autopilot-phase2` launch arguments (see scripts/smoke-auto.sh).
/// Performs the same actions a user performs manually — loads the user-supplied
/// test URL, taps Import, opens the reader, scrolls — and logs one
/// `[SMOKE] step=...` line per step. Never touches cookies, tokens, or page content.
@MainActor
final class SmokeAutopilot {
    private static let log = Logger(subsystem: "dev.chapterly", category: "smoke-diagnostics")

    private unowned let env: AppEnvironment
    private let stepTimeout: Duration = .seconds(30)
    private let pollInterval: Duration = .milliseconds(500)
    private var passCount = 0
    private var failCount = 0

    init(env: AppEnvironment) {
        self.env = env
    }

    func start() {
        Task { @MainActor in
            if AppEnvironment.isAutopilotPhase2 {
                await runPhase2()
            } else {
                await runPhase1()
            }
            Self.log.notice("[SMOKE] autopilot=complete pass=\(self.passCount) fail=\(self.failCount)")
        }
    }

    // MARK: - Phase 1: auth → collection → import → reader → css → progress save

    private func runPhase1() async {
        guard let testURL = Self.testURL() else {
            fail("auth", "missing_-SmokeTestURL_launch_argument")
            return
        }
        env.browse.load(testURL)

        let loaded = await waitUntil { [env] in
            env.browse.currentURL != nil && !env.browse.webView.isLoading
        }
        let onLogin = env.browse.currentURL?.path.contains("/login") ?? false
        guard loaded, !onLogin else {
            fail("auth", onLogin ? "not_logged_in" : "page_load_timeout")
            return
        }
        pass("auth")

        guard await waitUntil({ [env] in env.browse.isOnCollectionPage }) else {
            fail("collection_detect", "url_path_does_not_contain_/collection/")
            return
        }
        pass("collection_detect")

        env.browse.runCollectionImport()
        let imported = await waitUntil { [env] in
            env.importedCountThisSession > 0 && ((try? env.store.collectionCount()) ?? 0) > 0
        }
        guard imported else {
            fail("import", "no_chapters_imported")
            return
        }
        pass("import")

        guard let chapter = firstChapter() else {
            fail("open_reader", "no_chapter_in_store")
            return
        }
        guard await openReader(chapter, stepName: "open_reader") else { return }
        pass("open_reader")

        let cssProbe = "document.getElementById('\(ReaderStyler.styleElementID)') !== null"
        let cssApplied = await waitUntil { [env] in
            await Self.jsBool(env.reader.webView, cssProbe)
        }
        guard cssApplied else {
            fail("reader_css", "style_element_not_found")
            return
        }
        pass("reader_css")

        env.reader.webView.evaluateJavaScript(
            ReaderStyler.restoreScrollScript(progress: 0.5), completionHandler: nil)
        let saved = await waitUntil {
            guard let p = chapter.readingProgress else { return false }
            return SmokeCheck.approximatelyEqual(p, 0.5, tolerance: 0.1)
        }
        guard saved else {
            let actual = chapter.readingProgress.map { String(format: "%.2f", $0) } ?? "nil"
            fail("progress_save", "stored_progress=\(actual)")
            return
        }
        pass("progress_save")
    }

    // MARK: - Phase 2: progress restore on relaunch

    private func runPhase2() async {
        guard let chapter = firstChapterWithProgress(),
              let expected = chapter.readingProgress else {
            fail("progress_restore", "no_saved_progress_found")
            return
        }
        guard await openReader(chapter, stepName: "progress_restore") else { return }

        // ReaderView schedules the scroll restore 0.6 s after load; poll until the
        // actual scroll position approaches the stored progress.
        let restored = await waitUntil { [env] in
            guard let actual = await Self.scrollProgress(of: env.reader.webView) else { return false }
            return SmokeCheck.approximatelyEqual(actual, expected, tolerance: 0.1)
        }
        guard restored else {
            let actual = await Self.scrollProgress(of: env.reader.webView)
                .map { String(format: "%.2f", $0) } ?? "nil"
            let want = String(format: "%.2f", expected)
            fail("progress_restore", "scroll=\(actual)_expected=\(want)")
            return
        }
        pass("progress_restore")
    }

    // MARK: - Shared steps

    /// Presents the real ReaderView (via AppRootView's smoke-only fullScreenCover)
    /// and waits for the chapter page to finish loading.
    private func openReader(_ chapter: LocalChapterModel, stepName: String) async -> Bool {
        env.autopilotReaderTarget = AutopilotReaderTarget(id: chapter.id, chapter: chapter)
        let loaded = await waitUntil { [env] in
            env.reader.currentURL != nil && !env.reader.webView.isLoading
        }
        if !loaded {
            fail(stepName, "reader_load_timeout")
        }
        return loaded
    }

    // MARK: - Helpers

    private func waitUntil(_ condition: @MainActor () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + stepTimeout
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: pollInterval)
        }
        return false
    }

    private func firstChapter() -> LocalChapterModel? {
        guard let collection = (try? env.store.collections())?.first else { return nil }
        return env.store.orderedChapters(of: collection).first
    }

    private func firstChapterWithProgress() -> LocalChapterModel? {
        guard let collection = (try? env.store.collections())?.first else { return nil }
        return env.store.orderedChapters(of: collection).first { $0.readingProgress != nil }
    }

    private static func testURL() -> URL? {
        guard let raw = UserDefaults.standard.string(forKey: "SmokeTestURL") else { return nil }
        return URL(string: raw)
    }

    private static func jsBool(_ webView: WKWebView, _ js: String) async -> Bool {
        ((try? await webView.evaluateJavaScript(js)) as? Bool) ?? false
    }

    private static func scrollProgress(of webView: WKWebView) async -> Double? {
        let js = """
        (function () {
          var doc = document.documentElement;
          var max = doc.scrollHeight - window.innerHeight;
          return max > 0 ? window.scrollY / max : 0;
        })()
        """
        return (try? await webView.evaluateJavaScript(js)) as? Double
    }

    private func pass(_ step: String) {
        passCount += 1
        let line = SmokeReport.stepLine(step: step, pass: true, reason: nil)
        Self.log.notice("[SMOKE] \(line, privacy: .public)")
    }

    private func fail(_ step: String, _ reason: String) {
        failCount += 1
        let line = SmokeReport.stepLine(step: step, pass: false, reason: reason)
        Self.log.notice("[SMOKE] \(line, privacy: .public)")
    }
}
#endif
```

Notes for the implementer:

- A step failure aborts the remaining chain (later steps depend on earlier ones), but `autopilot=complete` is always emitted, so the driver never hangs waiting.
- `unowned let env` avoids the retain cycle (`AppEnvironment` owns the autopilot).
- The async `evaluateJavaScript` overload throws when the result is non-serializable; `try?` + cast handles all probe failures as `false`/`nil`.

- [ ] **Step 2: Build to verify compilation**

Run:
```bash
xcodebuild build -project Chapterly.xcodeproj -scheme Chapterly \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

(If the only booted/available device differs, list with `xcrun simctl list devices available` and substitute the name.)

- [ ] **Step 3: Commit Tasks 2+3 together**

```bash
git add App/AppEnvironment.swift App/SmokeAutopilot.swift
git commit -m "Add debug-only SmokeAutopilot step machine behind --smoke-autopilot"
```

---

### Task 4: Present the reader from `AppRootView` in autopilot mode

**Files:**
- Modify: `App/AppRootView.swift`

- [ ] **Step 1: Add the smoke-only fullScreenCover**

Replace the whole body of `App/AppRootView.swift` with:

```swift
import SwiftUI

struct AppRootView: View {
    @State private var env = AppEnvironment()

    var body: some View {
        TabView {
            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
                .accessibilityIdentifier("smoke.browseTab")
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .accessibilityIdentifier("smoke.libraryTab")
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .accessibilityIdentifier("smoke.settingsTab")
        }
        .environment(env)
        .modelContainer(env.store.container)
        #if DEBUG
        .fullScreenCover(item: Binding(
            get: { env.autopilotReaderTarget },
            set: { env.autopilotReaderTarget = $0 })) { target in
            ReaderView(chapter: target.chapter)
                .environment(env)
                .modelContainer(env.store.container)
        }
        #endif
    }
}
```

Note: the explicit `.environment(env)` / `.modelContainer` on the cover content is
required — a fullScreenCover does not inherit environment values injected *below*
its attachment point in the modifier chain.

- [ ] **Step 2: Build to verify compilation**

Run:
```bash
xcodebuild build -project Chapterly.xcodeproj -scheme Chapterly \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add App/AppRootView.swift
git commit -m "Present ReaderView from autopilot target in smoke builds"
```

---

### Task 5: `.env.example` entry

**Files:**
- Modify: `.env.example`

Rules: never read or print `.env` itself. Only touch `.env.example`.

- [ ] **Step 1: Append the key to `.env.example`**

Append to `.env.example`:

```bash
# Patreon collection URL used by scripts/smoke-auto.sh (any collection you can
# access while logged in; the app only loads it the way a user would).
SMOKE_TEST_URL=https://www.patreon.com/collection/REPLACE_ME
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "Document SMOKE_TEST_URL in .env.example"
```

---

### Task 6: `scripts/smoke-auto.sh` driver

**Files:**
- Create: `scripts/smoke-auto.sh`

- [ ] **Step 1: Create the script**

Create `scripts/smoke-auto.sh` with the exact content below, then `chmod +x scripts/smoke-auto.sh`:

```bash
#!/usr/bin/env bash
# Fully automated smoke test driver. Exit codes:
#   0  all steps passed (goal condition met)
#   1  one or more steps failed / build failed / timeout
#   2  not logged in to Patreon (manual login required once)
#   3  configuration error (missing SMOKE_TEST_URL or preflight failure)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SMOKE_DIR="$PROJECT_DIR/build/smoke"
SCHEME="Chapterly"
PROJECT="Chapterly.xcodeproj"
BUNDLE_ID="dev.chapterly.Chapterly"
PHASE1_TIMEOUT=180
PHASE2_TIMEOUT=90
EXPECTED_STEPS=7
LOG_PREDICATE='subsystem == "dev.chapterly" AND category == "smoke-diagnostics"'

mkdir -p "$SMOKE_DIR"

# --- Config ---
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
fi
if [ -z "${SMOKE_TEST_URL:-}" ]; then
  echo "ERROR: SMOKE_TEST_URL is not set."
  echo "Add this line to .env (see .env.example):"
  echo "  SMOKE_TEST_URL=https://www.patreon.com/collection/<your-collection-id>"
  exit 3
fi

# --- Preflight (reuses smoke-diagnostics.sh checks) ---
if ! ./scripts/smoke-diagnostics.sh preflight-only; then
  echo "Preflight failed — see build/smoke/preflight-report.md"
  exit 3
fi

BOOTED_UDID=$(xcrun simctl list devices booted -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('state') == 'Booted':
            print(d['udid']); sys.exit(0)
sys.exit(1)
")
DESTINATION="platform=iOS Simulator,id=$BOOTED_UDID"

# --- Build & install (never uninstall/erase: preserves Patreon login) ---
echo "--- Build ---"
if ! xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
    -configuration Debug CODE_SIGNING_ALLOWED=NO \
    > "$SMOKE_DIR/auto-build.log" 2>&1; then
  tail -30 "$SMOKE_DIR/auto-build.log"
  echo "Build failed — full log: $SMOKE_DIR/auto-build.log"
  exit 1
fi

APP_PATH="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings \
  -configuration Debug -destination "$DESTINATION" 2>/dev/null \
  | grep "BUILT_PRODUCTS_DIR" | head -1 | awk '{print $3}')/Chapterly.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: built app not found at $APP_PATH"
  exit 1
fi
xcrun simctl install "$BOOTED_UDID" "$APP_PATH"
echo "Installed $APP_PATH"

# --- Phase runner ---
run_phase() { # $1=phase-arg $2=timeout-seconds $3=label
  local phase_arg="$1" timeout="$2" label="$3" start waited=0
  start=$(date '+%Y-%m-%d %H:%M:%S')
  xcrun simctl terminate "$BOOTED_UDID" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$BOOTED_UDID" "$BUNDLE_ID" \
    --smoke-diagnostics "$phase_arg" -SmokeTestURL "$SMOKE_TEST_URL"
  echo "--- $label launched; waiting for autopilot=complete (max ${timeout}s) ---"
  while [ "$waited" -lt "$timeout" ]; do
    sleep 5
    waited=$((waited + 5))
    xcrun simctl spawn "$BOOTED_UDID" log show --predicate "$LOG_PREDICATE" \
      --style compact --start "$start" 2>/dev/null \
      > "$SMOKE_DIR/auto-$label.log" || true
    if grep -q "autopilot=complete" "$SMOKE_DIR/auto-$label.log"; then
      echo "$label complete after ${waited}s"
      return 0
    fi
  done
  echo "$label TIMEOUT after ${timeout}s (no autopilot=complete in log)"
  return 1
}

rm -f "$SMOKE_DIR"/auto-phase1.log "$SMOKE_DIR"/auto-phase2.log

PHASE_FAIL=0
run_phase "--smoke-autopilot" "$PHASE1_TIMEOUT" "phase1" || PHASE_FAIL=1

if [ "$PHASE_FAIL" -eq 0 ] \
   && ! grep -q "step=auth result=fail" "$SMOKE_DIR/auto-phase1.log"; then
  run_phase "--smoke-autopilot-phase2" "$PHASE2_TIMEOUT" "phase2" || PHASE_FAIL=1
fi

# --- Parse results ---
STEPS=$(grep -hoE "step=[a-z_]+ result=(pass|fail)( reason=[^ \"]+)?" \
  "$SMOKE_DIR"/auto-phase*.log 2>/dev/null || true)

{
  echo "# Smoke Auto Report"
  echo ""
  echo "Date: $(date)"
  echo ""
  echo '```'
  echo "$STEPS"
  echo '```'
} > "$SMOKE_DIR/auto-report.md"

echo ""
echo "=== Step results ==="
echo "${STEPS:-<none captured>}"

capture_failure_artifacts() {
  xcrun simctl io "$BOOTED_UDID" screenshot "$SMOKE_DIR/current-screen.png" 2>/dev/null || true
  cat "$SMOKE_DIR"/auto-phase*.log > "$SMOKE_DIR/app.log" 2>/dev/null || true
  echo "Artifacts: $SMOKE_DIR/current-screen.png, $SMOKE_DIR/app.log, $SMOKE_DIR/auto-report.md"
}

if echo "$STEPS" | grep -q "step=auth result=fail reason=not_logged_in"; then
  capture_failure_artifacts
  echo ""
  echo "NOT LOGGED IN: open the Simulator, log into Patreon inside the app once, then re-run."
  exit 2
fi

PASS_COUNT=$(echo "$STEPS" | grep -c "result=pass" || true)
FAIL_COUNT=$(echo "$STEPS" | grep -c "result=fail" || true)

if [ "$PHASE_FAIL" -ne 0 ] || [ "$FAIL_COUNT" -gt 0 ] || [ "$PASS_COUNT" -lt "$EXPECTED_STEPS" ]; then
  capture_failure_artifacts
  echo ""
  echo "FAIL: pass=$PASS_COUNT fail=$FAIL_COUNT expected=$EXPECTED_STEPS"
  exit 1
fi

echo ""
echo "PASS: all $EXPECTED_STEPS steps passed — goal condition met"
exit 0
```

- [ ] **Step 2: Syntax-check the script**

Run: `bash -n scripts/smoke-auto.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 3: Verify the config guard without touching .env state**

Run: `SMOKE_TEST_URL="" bash -c 'cd "$(git rev-parse --show-toplevel)" && env -u SMOKE_TEST_URL ./scripts/smoke-auto.sh' ; echo "exit=$?"`

Only valid if `.env` lacks the key; if the user already added `SMOKE_TEST_URL` to `.env`, skip this step (the guard is still covered by code review).
Expected when key missing: `ERROR: SMOKE_TEST_URL is not set.` and `exit=3`

- [ ] **Step 4: Commit**

```bash
git add scripts/smoke-auto.sh
git commit -m "Add smoke-auto.sh automated smoke test driver"
```

---

### Task 7: End-to-end run and fix loop

**Files:** none new — this validates everything against the real logged-in simulator.

Precondition: the user has added `SMOKE_TEST_URL=<their collection URL>` to `.env`
(ask them to do this — do not read or edit `.env` yourself), the Simulator is booted,
and the app is logged into Patreon (state already preserved from earlier sessions).

- [ ] **Step 1: Run the deterministic gate first**

Run: `./scripts/verify.sh`
Expected: build succeeds, all ChapterlyCore tests pass

- [ ] **Step 2: Run the automated smoke loop**

Run: `./scripts/smoke-auto.sh ; echo "exit=$?"`
Expected: `PASS: all 7 steps passed — goal condition met` and `exit=0`

- [ ] **Step 3: If exit != 0, debug per the standard loop**

- `exit=2` → tell the user to log into Patreon in the Simulator once, then re-run.
- `exit=1` → read `build/smoke/auto-report.md` + `build/smoke/auto-phase1.log` /
  `auto-phase2.log` + `build/smoke/current-screen.png`, identify the failing step,
  make the smallest fix (timeout bump, selector fix, timing fix), re-run.
  Follow superpowers:systematic-debugging — no guessing, logs first.
- `exit=3` → configuration problem; report the missing piece to the user.

- [ ] **Step 4: Commit any fixes made during the loop**

```bash
git add -A App ChapterlyCore scripts
git commit -m "Fix smoke autopilot issues found in first automated run"
```

(Only if fixes were needed; otherwise skip.)

---

### Task 8: Documentation updates

**Files:**
- Modify: `CLAUDE.md` (project)
- Propose only (do NOT edit without user confirmation): `README.md`

- [ ] **Step 1: Add a smoke-auto section to project CLAUDE.md**

In `CLAUDE.md`, after the "Smoke Diagnostics Command" section, add:

```markdown
### Automated Smoke Loop Command

Use this for fully automated smoke testing (login state must already exist in the
Simulator):

​```bash
./scripts/smoke-auto.sh
​```

Requires `SMOKE_TEST_URL` in `.env` (see `.env.example`). The script builds,
installs (never erases), launches the app twice with `--smoke-autopilot` /
`--smoke-autopilot-phase2`, and parses `[SMOKE] step=` lines.

Exit codes:

- `0` — all 7 steps passed (auth, collection_detect, import, open_reader,
  reader_css, progress_save, progress_restore)
- `1` — a step failed or timed out; read `build/smoke/auto-report.md`,
  `build/smoke/auto-phase1.log`, `build/smoke/auto-phase2.log`,
  `build/smoke/current-screen.png`
- `2` — not logged in; ask the user to log into Patreon in the Simulator once
- `3` — configuration/preflight error

The autopilot lives in `App/SmokeAutopilot.swift`, is compiled only in Debug, and
only runs with the explicit launch arguments. It must never automate login or
touch cookies/tokens (see Patreon Login Rules above).
```

(Strip the zero-width characters around the inner code fence when writing the real file — they exist here only to nest the fence.)

- [ ] **Step 2: Propose the README change to the user (gate)**

Per the user's global README consistency gate: do not edit `README.md` directly.
Tell the user: README's verification/testing section should mention
`./scripts/smoke-auto.sh` (one command, exit 0 = full MVP smoke pass, requires
`SMOKE_TEST_URL` in `.env`). Ask for confirmation, and only edit `README.md` after
they approve. If localized READMEs exist, update them in the same confirmed change.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "Document smoke-auto automated smoke loop in CLAUDE.md"
```

---

## Verification Checklist (after all tasks)

1. `cd ChapterlyCore && swift test` → all pass (includes new `SmokeSupportTests`)
2. `./scripts/verify.sh` → passes (unchanged behavior)
3. `bash -n scripts/smoke-auto.sh` → clean
4. `./scripts/smoke-auto.sh` → exit 0 with all 7 steps `result=pass`
5. Release safety: `SmokeAutopilot.swift`, `autopilotReaderTarget`, and the
   fullScreenCover are all inside `#if DEBUG`; activation additionally requires the
   `--smoke-autopilot*` launch argument.
6. Compliance: no new code reads cookies/tokens/page bodies; log lines contain only
   step names, booleans, counts, progress numbers, and the user-supplied URL.
```
