# Smoke-Auto: Fully Automated Smoke Test Loop

**Date:** 2026-06-10
**Status:** Approved

## Problem

The current smoke workflow (`scripts/smoke-diagnostics.sh`) builds, installs, launches
with `--smoke-diagnostics`, and captures logs/screenshots — but a human still has to
navigate to the test article, trigger the import, open the reader, and judge the
results by eye. Since the simulator preserves the Patreon login session across app
reinstalls, the manual steps are no longer login-bound and can be automated.

Goal: one command, `./scripts/smoke-auto.sh`, that exercises the full MVP flow and
exits `0` only when every step passes. This gives the `/goal` evaluator (and Claude's
fix-and-retry loop) a deterministic, machine-checkable completion condition.

## Non-Goals

- No automated login, CAPTCHA, or 2FA handling. If the session is expired, the run
  reports it and asks the user to log in manually once.
- No changes to `verify.sh` (it stays CI-safe, no real-Patreon dependency).
- No reading, copying, or exporting of cookies, tokens, or Patreon API traffic.
  The autopilot only performs the same actions a user performs by hand
  (load a URL the user supplied, tap Import, open the reader, scroll).
- No new XCUITest target in this iteration.

## Architecture

Two pieces: a debug-only **autopilot** inside the app that drives the real UI flow
and reports each step as a `[SMOKE]` log line, and a **driver script** that builds,
launches, parses those lines, and turns them into an exit code.

### 1. App: `App/SmokeAutopilot.swift` (debug-gated)

Activation requires both gates:

- compiled only under `#if DEBUG`
- runs only when launch arguments contain `--smoke-autopilot`

The test URL is passed per-launch as `-SmokeTestURL <url>` (read via
`UserDefaults`/`ProcessInfo`); the app never persists it.

The autopilot is a step machine owned by `AppEnvironment` (same pattern as the
existing `isSmokeMode` diagnostics). Each step emits:

```text
[SMOKE] step=<name> result=pass|fail reason=<reason-if-fail>
```

Every step has a timeout (default 30 s, per-step override allowed). A timeout marks
the step `fail reason=timeout` and the run continues to emit remaining results
rather than hanging. The run always terminates with:

```text
[SMOKE] autopilot=complete pass=<n> fail=<n>
```

**Phase 1 (first launch, `--smoke-autopilot`):**

| step | action | pass condition |
|------|--------|----------------|
| `auth` | `browse.load(testURL)` | final URL is not redirected to `/login` |
| `collection_detect` | wait for page load | `browse.isOnCollectionPage == true` |
| `import` | `browse.runCollectionImport()` | `store.collectionCount() > 0` and imported chapter count > 0 |
| `open_reader` | publish chapter via observable state; `AppRootView` (smoke mode only) presents the real `ReaderView` for the first chapter | reader web view finishes loading |
| `reader_css` | evaluate JS probe for the `ReaderStyler` injection marker | marker node exists in DOM |
| `progress_save` | JS-scroll to ~50%; progress tracker reports through the normal `onProgress` path | stored progress for the chapter ≈ 0.5 (±0.1) |

**Phase 2 (second launch, `--smoke-autopilot-phase2`):**

| step | action | pass condition |
|------|--------|----------------|
| `progress_restore` | reopen the same chapter via the same presentation path | scroll position after restore ≈ stored progress (±0.1) |

The `auth` failure is special-cased: it emits
`[SMOKE] step=auth result=fail reason=not_logged_in` so the driver can map it to a
distinct exit code.

Diagnostics rules from CLAUDE.md apply: no cookies, tokens, headers, page bodies, or
personal data in any log line. URLs logged are the user-supplied test URL and
chapter post URLs only (already stored locally by design — see COMPLIANCE.md).

### 2. Driver: `scripts/smoke-auto.sh`

1. Load `SMOKE_TEST_URL` from `.env`. Missing/empty → print setup instructions,
   exit `3`.
2. Run the same preflight as `smoke-diagnostics.sh` (XcodeGen, scheme, booted
   simulator). Preflight failure → exit non-zero with the existing report files.
3. Build and `simctl install` (never uninstall, never erase — login state must
   survive).
4. Launch phase 1:
   `simctl launch <udid> dev.chapterly.Chapterly --smoke-diagnostics --smoke-autopilot -SmokeTestURL "$SMOKE_TEST_URL"`.
5. Poll the unified log (`log show`, same predicate as today) until
   `autopilot=complete` appears or a global timeout (~3 min) expires.
6. Terminate, relaunch with `--smoke-autopilot-phase2`, poll again.
7. Parse all `step=` lines into a result table printed to stdout and saved to
   `build/smoke/auto-report.md`.
8. On any failure, capture `build/smoke/current-screen.png` and `build/smoke/app.log`
   (reuse existing capture code paths).

**Exit codes:**

| code | meaning |
|------|---------|
| 0 | all steps passed — goal condition met |
| 1 | one or more steps failed |
| 2 | `auth` failed (`not_logged_in`) — user must log in manually once |
| 3 | configuration error (missing `SMOKE_TEST_URL`, preflight failure) |

### 3. Configuration

- `.env` (gitignored, already exists): add `SMOKE_TEST_URL=<patreon collection or article URL>`
- `.env.example`: add the key with a placeholder and a one-line comment

### 4. Workflow with `/goal`

```text
User:   /goal ./scripts/smoke-auto.sh exits 0 (all smoke steps pass)
Claude: run script → read step table → smallest fix → rerun … until exit 0
        (exit 2 → stop and ask the user to log in manually, then resume)
```

## Error Handling

- Per-step timeout prevents hangs; the report always completes.
- Slow page loads are the main flake risk; timeouts are configurable in one place
  (constant in `SmokeAutopilot.swift`), and every failure ships with a screenshot.
- `import` failure keeps the existing page-structure dump behavior from
  `BrowseView` for markup-change diagnosis.
- Script is `set -euo pipefail` but parses results from the log, not from app exit
  status, so app crashes surface as missing `autopilot=complete` → global timeout
  → exit 1 with logs.

## Testing

- `ChapterlyCore` unit tests are unaffected; any pure logic added (e.g. step result
  parsing helpers, tolerance comparison) goes to `ChapterlyCore` with unit tests
  where practical.
- The autopilot itself is verified by running `./scripts/smoke-auto.sh` against the
  real logged-in simulator — that is its purpose.
- `verify.sh` remains the deterministic CI gate and is not modified.

## Compliance

Unchanged posture (see COMPLIANCE.md): the autopilot triggers the same in-app
actions a user performs manually, on a URL the user supplies. It does not touch the
website data store, does not intercept network traffic, and does not log content.
