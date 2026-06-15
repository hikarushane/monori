# AGENTS.md
## Debugging and Testing Rules

This project is an iOS app developed with Codex, superpowers, and subagent-driven-development.

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
6. Codex analyzes those outputs and fixes the app if needed.

Steps 1 and 3 may be performed by Codex itself via
`./scripts/ui-driver.sh` (see “Simulator UI Automation” below and
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
xcodebuild -list -project Chapterly.xcodeproj
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

### Simulator UI Automation (idb driver)

When a debugging, reproduction, or verification step needs someone to
interact with the running app (navigate, tap, swipe, visually confirm a
screen), Codex performs it via `./scripts/ui-driver.sh` instead of
asking the user. Codex sessions do not have the computer-use MCP; the
idb-based driver script is the only sanctioned way to drive the
Simulator from a shell.

Before driving, read `SIMULATOR_PLAYBOOK.md` at the repo root and
follow its driver B instructions. It defines the session bootstrap,
gesture recipes (device-point coordinates), verification loop,
human-verification handoff, and artifact paths.

Rules:

* Bootstrap first: `./scripts/ui-preflight.sh`, then
  `./scripts/ui-driver.sh doctor`. Exit 3 = not ready; report why and
  fall back to asking the user — never force-boot or erase a Simulator
  to make a check pass.
* Verify every action with a device screenshot
  (`./scripts/ui-driver.sh shot <desc>`) and view it; if you cannot
  view images, use `./scripts/ui-driver.sh describe` (accessibility
  tree with element frames in device points) as the state check.
* Prefer tap coordinates computed from `describe` frames — the app's
  `smoke.*` accessibility identifiers appear there — over guessing
  from pixels.
* Patreon login, CAPTCHA, Cloudflare human verification, 2FA, and
  email verification are always manual user steps. When one appears on
  screen, stop all input immediately, tell the user, and wait. All
  Patreon Login Rules below apply unchanged. Never type credentials
  with `ui-driver.sh text`.
* `verify.sh` stays headless and deterministic. Never call
  `ui-driver.sh` from `verify.sh`, other scripts, or CI.
* Never erase or reset the Simulator, never delete the app — same as
  everywhere else in this document.

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
* progress save/restore state
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

#### Post-footer verification is a manual user step

The post footer — the comment thread, "Related posts", and "From the collection" — sits at the very bottom of long chapters. Synthetic scrolling (idb swipe / `ui-driver.sh swipe`) is slow and unreliable over a long article and often never reaches it. **When a check requires scrolling to the post footer (e.g. confirming the comment thread loads, "Load more comments" works, or the promo sections are hidden), do not auto-scroll for a long time. Ask the user to manually scroll to that section and report what they see.** Everything above the footer (Library, TOC, reader top half, prefs panel) is still driven normally by the agent. This rule also applies to the smoke scripts: they stay headless and never try to drive to the footer.

---

### Progress Save / Restore Debugging

When debugging progress save and restore:

* use a deterministic local test where possible
* verify the storage key
* verify save timing
* verify restore timing
* verify the article identifier is stable
* verify the test does not depend on real Patreon content unless it is a manual smoke test

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
readerProgressEntriesBeforeClear = 12
readerProgressEntriesAfterClear = 0
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
- Fix: created the missing folder and regenerated Chapterly.xcodeproj
- Next step: open Xcode and press Cmd + R, or run ./scripts/smoke-diagnostics.sh after manual Patreon login
```

---

### Things Not To Do

Do not:

* skip failing tests to make the script pass
* remove tests because they fail
* disable diagnostics instead of fixing the underlying issue
* ask the user to inspect Xcode manually before checking available logs
* ask the user to perform Simulator UI steps that scripts/ui-driver.sh can perform (login, CAPTCHA, Cloudflare, and 2FA excepted)
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

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
