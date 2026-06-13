# SIMULATOR_PLAYBOOK — Agent-Driven Simulator UI Automation

How coding agents drive the iOS Simulator during debugging and smoke
verification. Companion to the "Simulator UI Automation" sections in
CLAUDE.md (Claude Code) and AGENTS.md (Codex and other agents).

Goal: the user is only ever needed for Patreon login, CAPTCHA, Cloudflare
human verification, 2FA, email verification — and, for driver A, the
one-time per-session computer-use access approval. Every other Simulator
interaction is the agent's job.

## Scope

Use UI driving for:

- reproducing UX issues (taps, swipes, navigation)
- driving manual smoke steps that shell scripts cannot automate
- visual verification after a fix

Never use UI driving for:

- `verify.sh`, unit tests, CI — those stay headless and deterministic
- anything on login / CAPTCHA / Cloudflare / 2FA screens
- typing credentials of any kind

## Drivers

| Driver | What | Who has it | Coordinate space |
|--------|------|------------|------------------|
| A | computer-use MCP (`mcp__computer-use__*`) | Claude Code desktop app sessions only | desktop-screenshot pixels |
| B | idb via `./scripts/ui-driver.sh` | any agent with shell access (Codex, Claude Code CLI, ...) | device points |

Prefer driver B when `./scripts/ui-driver.sh doctor` passes: device-point
coordinates don't depend on window position, taps work even with the
Simulator window in the background, and `describe` exposes accessibility
frames (including the app's `smoke.*` identifiers) so tap points can be
computed instead of guessed.

Use driver A when idb is unavailable or broken, or for anything outside
the rendered device screen — the Simulator menu bar, macOS dialogs,
permission prompts. Driver B cannot touch macOS chrome.

If neither driver works, fall back to the old workflow: ask the user to
perform the UI steps manually.

## Session bootstrap (once per session, in order)

1. **Readiness.** Run `./scripts/ui-preflight.sh`. It verifies a booted
   Simulator and the installed app, reports whether idb is installed,
   and writes `build/smoke/ui/baseline.png` plus `preflight.txt`.
   Exit 3 = not ready; report the reason. Never force-boot or erase to
   make it pass.
2. **Driver B check.** Run `./scripts/ui-driver.sh doctor`. Exit 0 =
   drive with B. Exit 3: read the FAIL line, then consider driver A.
3. **Driver A check (only if B is unavailable, or macOS chrome is
   involved).** ToolSearch query `computer-use` (max_results 30). If no
   `mcp__computer-use__*` tools exist in this session (CLI, web, and
   Codex sessions lack them), A is unavailable. Otherwise call
   `request_access` with applications `["Simulator"]` — the user
   approves once per session — then `open_application` with "Simulator"
   so the window is frontmost. If access is denied, fall back without
   complaining.
4. **Diagnostics (optional but recommended).** If you will need
   route/state logs, relaunch the app with the diagnostics flag BEFORE
   navigating — login survives terminate/launch, but in-app navigation
   state resets:

   ```bash
   xcrun simctl terminate booted dev.chapterly.Chapterly || true
   xcrun simctl launch booted dev.chapterly.Chapterly --smoke-diagnostics
   ```

   Collect logs later with `./scripts/smoke-diagnostics.sh` (writes
   `build/smoke/app.log`, UI hierarchy, screenshots).

## Verifying state after every action

- **Device truth** — `./scripts/ui-driver.sh shot <desc>` writes an
  auto-numbered `build/smoke/ui/step-NN-<desc>.png` and prints the
  path; then view the PNG. Use this to VERIFY state after every action,
  with either driver. Equivalent raw command:
  `xcrun simctl io booted screenshot build/smoke/ui/step-NN-<desc>.png`.
- **Element truth (driver B)** — `./scripts/ui-driver.sh describe`
  dumps the accessibility tree as JSON (also saved to
  `build/smoke/ui/describe-last.json`). Elements carry labels,
  identifiers (the app's `smoke.*` ids appear here), and frames in
  device points. Prefer tapping the center of a frame found here over
  eyeballing coordinates. Agents that cannot view images can use this
  as their primary state check. Caveat: content inside the reader's
  web view may not be exposed — use coordinate recipes there.
- **Desktop coordinates (driver A only)** —
  `mcp__computer-use__screenshot`. Use this only to LOCATE the
  Simulator window and compute click/drag coordinates. Take a fresh
  desktop screenshot before computing any coordinate, and never move or
  resize the Simulator window mid-run — it invalidates every cached
  coordinate.
- **Coordinate spaces.** Driver A coordinates live in desktop-screenshot
  pixels. Driver B coordinates are device points. Device-screenshot PNG
  pixels = points × scale; get all three numbers from
  `./scripts/ui-driver.sh info`.

## Gesture recipes

"Content area" = the rendered iOS screen inside the Simulator window
(exclude the macOS title bar and window chrome). W×H below = device
point size from `./scripts/ui-driver.sh info`.

| ID | Gesture | Driver A default (desktop coords) | Driver B default (device points) |
|----|---------|-----------------------------------|----------------------------------|
| R1 | Tap a control | `left_click` at the center of the target in the latest desktop screenshot | `tap` at the center of the element's frame from `describe` |
| R2 | Tap a list row | `left_click` on the row's title text, x ≈ 30% of content width | `tap` at the center of the row's frame from `describe` |
| R3 | Back edge-swipe | `left_click_drag` from (content left edge + 3 px, content vertical middle) to (content left edge + 260 px, same y) | `./scripts/ui-driver.sh back` (swipe 0,H/2 → 260,H/2, delta 20) |
| R4 | Reader center-tap (chrome toggle) | `left_click` at the exact center of the content area | `tap W/2 H/2` |
| R5 | Reader swipe-to-leave | Same motion as R3 — the reader uses a left-edge gesture | Same as R3 (`back`) |
| R6 | Scroll | `scroll` with the pointer over the content area | `swipe W/2 0.7×H W/2 0.3×H` (drag up = scroll content down) |
| R7 | Type into a focused field | `type` tool | `text <string>` — NEVER credentials |

After each gesture: device screenshot → view → confirm the expected
change before issuing the next input.

## Verified recipes log

Updated by live calibration. Where a recipe needed different parameters
than the defaults above, the row here wins.

| Date | Driver | Recipe | Result | Notes |
|------|--------|--------|--------|-------|
| (pending first calibration) | | | | |

## Driver B setup

One-time machine setup (already done if `./scripts/ui-driver.sh doctor`
passes):

```bash
brew tap facebook/fb
brew install idb-companion
brew install pipx && pipx ensurepath
pipx install fb-idb
```

`idb` lands in `~/.local/bin`; the project scripts add that to PATH
themselves. Verify with `idb list-targets` (the booted Simulator should
appear) and `./scripts/ui-driver.sh doctor`.

### Known install issues (2026-06-13)

- **idb-companion**: failed to install — Homebrew requires "Command Line
  Tools for Xcode 26.3" (current CLT are too outdated). Fix: update CLT
  from System Settings → Software Update, then re-run `brew install
  idb-companion`.
- **fb-idb 1.1.7**: incompatible with Python 3.14 — `asyncio.get_event_loop()`
  raises `RuntimeError: There is no current event loop in thread 'MainThread'`.
  Fix: install Python ≤ 3.12 via pyenv or brew, then `pipx install fb-idb`
  with that Python. Until both issues are resolved, driver B is unavailable
  on this machine; use driver A (computer-use MCP) or manual steps.

If install or runtime fails against the current Xcode (fb-idb is in
maintenance mode), record the failure here with the date and exact
error, drive with driver A or manual fallback, and leave driver B alone
until a dedicated follow-up plan addresses it.

## Human-verification handoff

Triggers — any of these visible in a screenshot:

- Patreon login form (email or password fields)
- CAPTCHA of any kind
- Cloudflare "Verify you are human" interstitial
- 2FA code prompt, email-verification prompt
- any payment or App Store sheet

Protocol:

1. STOP all input immediately. No clicking, typing, or scrolling on
   that screen — with either driver.
2. Save a device screenshot under `build/smoke/ui/` for the record.
3. Tell the user exactly what is on screen and the one action needed,
   e.g. 「模擬器出現 Cloudflare 真人驗證，請完成後回覆 done」.
4. Wait. Do not poll with clicks.
5. On resume, take a fresh device screenshot and continue only if the
   challenge is gone.

## Failure escalation

- Same target missed 3 times → stop. If the other driver is available,
  try that single step once with it. Otherwise attach the screenshots,
  ask the user to do that single step manually, then continue driving.
- Gesture not recognized after 3 attempts → try the on-screen
  alternative once (e.g. a visible back button instead of an
  edge-swipe), then report.
- In reports, distinguish: "gesture not recognized" (automation input
  problem) vs "gesture recognized but the app did nothing" (an
  app-layer finding — that is a bug report, not an automation failure).

## Forbidden

- Erasing or resetting the Simulator, deleting the app, Device > Erase menu
- Typing credentials; any interaction with login/CAPTCHA/Cloudflare screens
- Changing iOS Settings, opening the App Store
- Tapping links that leave patreon.com (the app opens external SSO in
  Safari by design — avoid triggering it)
- Moving or resizing the Simulator window mid-run (driver A)
- Raw `idb install`, `idb uninstall`, `idb erase`, `idb boot`,
  `idb shutdown` — app/device lifecycle stays with the smoke scripts
  and `xcrun simctl`; `./scripts/ui-driver.sh` is the sanctioned idb
  entry point
- Calling computer-use or `ui-driver.sh` from shell scripts,
  `verify.sh`, or CI

## Artifacts

Everything under `build/smoke/ui/` (gitignored): `preflight.txt`,
`baseline.png`, `step-NN-<desc>.png` (auto-numbered by `ui-driver.sh
shot`), `describe-last.json`. Prefix shot descriptions with `a-` or
`b-` when calibrating both drivers, and `rehearsal-` for rehearsal
runs, so a run can be replayed from filenames alone.
