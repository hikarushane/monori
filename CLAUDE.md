# CLAUDE.md
## Debugging and Testing Rules

This project is an iOS app developed with Claude Code, superpowers, and subagent-driven-development.

The user is not a professional iOS developer. Do not rely on the user to interpret raw Xcode errors, inspect internal app state, or manually describe screens when the project can collect diagnostics itself.

The goal is to keep debugging reproducible, scriptable, and safe.

---

### Core Rule

Do not guess.

When something fails, first identify which stage failed:

1. XcodeGen / project generation
2. Xcode project / scheme discovery
3. build
4. unit tests
5. UI tests
6. simulator boot / install / launch
7. app runtime state
8. Patreon login / authenticated content state
9. smoke test flow

Collect logs before changing code.

Make the smallest fix that addresses the current failure.

Run the relevant script again after the fix.

---

### Standard Verification Command

Use this for deterministic automated checks:

```bash
./scripts/verify.sh
```

`verify.sh` is the main automated verification entry point.

It may run:

* hook config regression check (`scripts/check-hooks.sh`, guards fa5bb64)
* XcodeGen, if needed
* build
* unit tests
* UI tests
* deterministic integration tests

Do not put real Patreon login, CAPTCHA, 2FA, email verification, or paid-content manual checks into `verify.sh`.

`verify.sh` must remain suitable for local repeatable testing and CI.

---

### Smoke Diagnostics Command

Use this for semi-automated manual smoke testing:

```bash
./scripts/smoke-diagnostics.sh
```

This script is for cases that require a real Patreon login.

The correct workflow is:

1. The user manually opens the app in the iOS Simulator.
2. The user manually logs into Patreon.
3. The user navigates to the relevant article or collection page.
4. The user runs:

```bash
./scripts/smoke-diagnostics.sh
```

5. The script collects screenshots, logs, UI hierarchy, and app diagnostics.
6. Claude analyzes those outputs and fixes the app if needed.

Steps 1 and 3 may be performed by Claude itself — via the computer-use
MCP or `./scripts/ui-driver.sh` (see “Simulator UI Automation” below and
`SIMULATOR_PLAYBOOK.md`). Step 2 (Patreon login) and any CAPTCHA /
Cloudflare human verification are always manual user steps.

Do not ask the user repeatedly: “What page are you on?” or “Do you see the button?”

Instead, improve diagnostics so the app can report:

* current screen / route
* auth state
* collection state
* whether collection banner is visible
* whether import action is available
* why the import action is hidden
* detected chapter count
* relevant non-secret URL or article identifier, if safe

---

### Automated Smoke Loop Command

Use this for the full MVP smoke loop after the Simulator is already manually logged into Patreon and `.env` contains `SMOKE_TEST_URL`:

```bash
./scripts/smoke-auto.sh
```

`smoke-auto.sh` drives the logged-in Simulator through:

* auth check
* collection page detection
* chapter import
* reader open
* reader CSS check
* bookmark save
* bookmark restore after relaunch
* reader opens at top

`EXPECTED_STEPS=8`. Exit codes:

* `0` means all smoke steps passed
* `1` means a build, smoke step, or timeout failed
* `2` means Patreon login is missing
* `3` means configuration or preflight failed

The script must preserve Patreon login state. Do not uninstall the app, erase the Simulator, reset Simulator contents, or automate Patreon login for this command.

Artifacts are written under:

```text
build/smoke/
```

Always inspect `build/smoke/auto-report.md`, `build/smoke/auto-phase1.log`, `build/smoke/auto-phase2.log`, and `build/smoke/app.log` before changing code after a failure.

---

### Smoke Diagnostics Output

`scripts/smoke-diagnostics.sh` should write files under:

```text
build/smoke/
```

Expected files:

```text
build/smoke/preflight.log
build/smoke/xcodegen.log
build/smoke/xcodebuild-list.log
build/smoke/simulators.log
build/smoke/app.log
build/smoke/current-screen.png
build/smoke/current-run.mov
build/smoke/preflight-report.md
```

If the script fails, always inspect the relevant logs before modifying code.

Start with:

```bash
cat build/smoke/preflight-report.md
tail -100 build/smoke/xcodegen.log
tail -100 build/smoke/xcodebuild-list.log
tail -100 build/smoke/app.log
```

---

### Preflight Diagnostics

Before smoke testing, `smoke-diagnostics.sh` must run preflight checks.

Check:

```bash
xcode-select -p
xcodebuild -version
xcrun --version
xcrun simctl list devices available
```

If the project uses XcodeGen, also check:

```bash
xcodegen --version
xcodegen generate
```

If `xcodegen generate` fails:

* stop immediately
* do not continue to build
* write the failure to `build/smoke/xcodegen.log`
* create or update `build/smoke/preflight-report.md`
* explain the likely cause in plain language
* exit with non-zero status

Common XcodeGen failure causes:

* invalid `project.yml` syntax
* missing source path
* wrong target name
* missing test target folder
* invalid package dependency
* unsupported XcodeGen version
* generated `.xcodeproj` not created

If `xcodebuild -list` fails:

* stop immediately
* write output to `build/smoke/xcodebuild-list.log`
* update `build/smoke/preflight-report.md`
* do not continue to smoke testing

If no suitable simulator is available:

* stop immediately
* list available simulators in `build/smoke/simulators.log`
* recommend a usable iPhone simulator
* update `build/smoke/preflight-report.md`

---

### XcodeGen Rules

If `project.yml` changes, regenerate the Xcode project:

```bash
xcodegen generate
```

After regenerating:

```bash
xcodebuild -list -project Monori.xcodeproj
```

Do not manually edit generated Xcode project files unless there is no other reasonable option.

Prefer changing `project.yml` and regenerating the project.

---

### Xcode and Simulator Rules

For normal code changes:

* do not restart the Simulator
* do not erase the Simulator
* do not delete the app
* do not reset content and settings

The user may need to preserve Patreon login state.

Only restart the Simulator when:

* the Simulator is frozen
* the app cannot launch after repeated attempts
* the issue is clearly caused by Simulator state corruption

Only erase the Simulator when explicitly testing fresh install behavior.

Do not erase the Simulator during Patreon smoke testing unless the user explicitly asks for it.

---

### Simulator UI Automation (computer-use MCP / idb)

When a debugging, reproduction, or verification step needs someone to
interact with the running app (navigate, tap, swipe, visually confirm a
screen), Claude performs it instead of asking the user. Two drivers
exist; read `SIMULATOR_PLAYBOOK.md` at the repo root before driving —
it defines the session bootstrap, gesture recipes, verification loop,
human-verification handoff, and artifact paths.

* Driver B (preferred): `./scripts/ui-driver.sh` — idb-based,
  device-point coordinates, works in any session with shell access.
  Run `./scripts/ui-preflight.sh` and `./scripts/ui-driver.sh doctor`
  before the first UI action.
* Driver A: the computer-use MCP (tools named `mcp__computer-use__*`),
  available in Claude Code desktop sessions only. Use it when idb is
  unavailable or broken, or for anything outside the device screen
  (Simulator menus, macOS dialogs). Load the tools with ToolSearch;
  call `request_access` for "Simulator" once per session.
* Non-Claude agents (Codex, etc.) get the same workflow through
  `AGENTS.md` and driver B.

Rules:

* Patreon login, CAPTCHA, Cloudflare human verification, 2FA, and email
  verification are always manual user steps. When one appears on
  screen, stop all input immediately, tell the user, and wait. All
  Patreon Login Rules below apply unchanged.
* Verify app state after every action with a device screenshot
  (`./scripts/ui-driver.sh shot <desc>` or `xcrun simctl io booted
  screenshot`); with driver B, prefer tap points computed from
  `./scripts/ui-driver.sh describe` frames.
* If neither driver is available or working, fall back to the old
  workflow and ask the user to perform the UI steps manually.
* `verify.sh` stays headless and deterministic. Never call computer-use
  or `ui-driver.sh` from scripts, `verify.sh`, or CI — they are for
  interactive agent sessions only.
* Never erase or reset the Simulator, never delete the app, never type
  credentials — same as everywhere else in this document.

---

### Patreon Login Rules

Never request, read, store, print, or automate:

* Patreon password
* email verification links
* CAPTCHA
* 2FA codes
* session cookies
* access tokens
* authorization headers

Do not attempt to bypass login protections.

Real Patreon login is a manual user step.

After the user logs in manually, diagnostics may inspect app state, screenshots, UI hierarchy, and non-secret logs.

Do not print secrets in logs.

Do not log:

* cookies
* bearer tokens
* auth headers
* refresh tokens
* password fields
* raw credential payloads

---

### Debug Launch Argument

Use this launch argument for diagnostic mode:

```text
--smoke-diagnostics
```

When the app is launched with `--smoke-diagnostics`, it may print safe diagnostic information.

Allowed diagnostics:

* current screen / route
* auth state as a boolean or enum
* current non-secret page type
* collection detected or not
* collection banner visible or not
* import chapters action available or not
* reason why import chapters is hidden
* detected chapter count
* reader CSS applied or not
* bookmark state
* independent data clearing status

Forbidden diagnostics:

* passwords
* cookies
* tokens
* authorization headers
* full private API payloads
* personal account information beyond what is necessary for debugging

Diagnostics must not change production behavior.

Keep diagnostic behavior behind Debug builds, test targets, or explicit launch arguments.

---

### UI Test Diagnostics

If a UI test target exists, add or maintain a diagnostic UI test.

The diagnostic UI test should:

* launch the app with `--smoke-diagnostics`
* print `XCUIApplication().debugDescription`
* check for important accessibility identifiers
* write useful output into the xcodebuild log
* not require real Patreon login

Useful identifiers:

```text
smoke.collectionBanner
smoke.importChaptersButton
smoke.readerTitle
smoke.readerWebView
smoke.chapterBookmarkButton
smoke.readerBookmarkButton
smoke.readerPrefsButton
smoke.readerDismissButton
smoke.refreshChaptersButton
smoke.refreshStatusBanner
smoke.clearDataButton
```

If an important UI element does not have an accessibility identifier, add one.

Do not use fragile UI tests based only on visible text if a stable identifier can be added.

---

### Import Chapters Debugging

When debugging the `Import chapters` flow, first locate the actual implementation.

Search for:

```text
Import chapters
Import Chapters
import chapters
collection
banner
chapter
```

Then answer these questions before changing behavior:

1. Which Swift file defines the import button?
2. Which state controls whether the button is visible?
3. Which state controls whether the collection banner is visible?
4. Does the current article have collection metadata?
5. Is the app on the expected article or collection screen?
6. Is the user authenticated?
7. Is the content loaded through the expected path?
8. Is the button hidden because data is missing, loading failed, or the screen is different?

If the button is hidden, diagnostics should explain why.

Example diagnostic output:

```text
screen = ArticleDetailView
authenticated = true
collectionBannerVisible = true
importChaptersAvailable = false
hiddenReason = collection metadata missing
detectedChapterCount = 0
```

---

### Reader CSS Debugging

When debugging reader CSS:

* verify the reader screen is actually loaded
* verify the expected article content exists
* verify CSS injection ran
* verify CSS did not run before the web view content loaded
* collect safe logs
* prefer deterministic tests with sample HTML where possible

Do not rely only on visual inspection.

If possible, add a test fixture with local HTML and verify CSS behavior without Patreon login.

Reader mode is always enabled for library chapters (`foreignPageTitle == nil`). The "Reader mode by default" toggle was removed from Settings — there is no per-chapter opt-out.

#### Post-footer verification is a manual user step

The post footer — the comment thread, "Related posts", and "From the collection" — sits at the very bottom of long chapters. Synthetic scrolling (idb swipe / `ui-driver.sh swipe`) is slow and unreliable over a long article and often never reaches it. **When a check requires scrolling to the post footer (e.g. confirming the comment thread loads, "Load more comments" works, or the promo sections are hidden), do not auto-scroll for a long time. Ask the user to manually scroll to that section and report what they see.** Everything above the footer (Library, TOC, reader top half, prefs panel) is still driven normally by the agent. This rule also applies to the smoke scripts: they stay headless and never try to drive to the footer.

---

### Bookmark Debugging

When debugging bookmark save and restore:

* Storage field: `isBookmarked: Bool` on `LocalChapterModel`
* Toggle method: `store.toggleBookmark(_:)` in `LibraryStore`
* Deterministic test: `testToggleBookmarkPersistsAndTogglesBack` in `LibraryStoreTests`
* Bookmark icon in TOC rows (`smoke.chapterBookmarkButton`) and reader top bar (`smoke.readerBookmarkButton`) share the same model — toggling one updates the other immediately
* No simulator erase needed; bookmark state is local SwiftData

Do not erase the Simulator if the goal is to preserve login state.

---

### Independent Data Clearing Debugging

When debugging independent data clearing:

* clearly separate app data from Patreon login/session state if the design requires that
* verify what data should be cleared
* verify what data should be preserved
* log safe counts or boolean states only
* do not print private content or tokens

Example safe diagnostics:

```text
bookmarkedChapterCountBeforeClear = 3
bookmarkedChapterCountAfterClear = 0
patreonSessionPreserved = true
```

---

### Reporting Back to the User

The user prefers plain language.

After debugging, report:

* what failed
* which file or script was involved
* what was changed
* which command was run
* whether it passed
* what remains manual
* what the user should do next

Do not paste huge raw logs unless the user asks.

Prefer this format:

```text
Result:
- verify.sh: passed
- smoke-diagnostics.sh: failed at XcodeGen
- Cause: project.yml referenced a missing test folder
- Fix: created the missing folder and regenerated Monori.xcodeproj
- Next step: open Xcode and press Cmd + R, or run ./scripts/smoke-diagnostics.sh after manual Patreon login
```

---

### Things Not To Do

Do not:

* skip failing tests to make the script pass
* remove tests because they fail
* disable diagnostics instead of fixing the underlying issue
* ask the user to inspect Xcode manually before checking available logs
* ask the user to perform Simulator UI steps that an available driver (computer-use MCP or scripts/ui-driver.sh) can perform (login, CAPTCHA, Cloudflare, and 2FA excepted)
* automate real Patreon login
* read `.env`
* read credentials
* read provisioning profiles
* print secrets
* erase Simulator during Patreon smoke testing
* make large architecture changes during debugging
* add new product features while fixing diagnostics

---

### Preferred Debugging Loop

Use this loop:

```text
1. Reproduce with the relevant script.
2. Collect logs and screenshots.
3. Identify the failing stage.
4. Inspect the smallest relevant code area.
5. Make the smallest safe fix.
6. Re-run the same script.
7. Report result in plain language.
```

Default commands:

```bash
./scripts/verify.sh
./scripts/smoke-diagnostics.sh
```

Use `verify.sh` for automated correctness.

Use `smoke-diagnostics.sh` for manual-login smoke test support.

When debugging, do not ask the user to manually inspect app state until you have first checked scripts, logs, screenshots, simulator state, and UI hierarchy diagnostics.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
