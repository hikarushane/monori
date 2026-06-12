# Keep-On Report — Library & Reader UX Overhaul

> Written: 2026-06-12, by Claude Code session analyzing the interrupted Codex run.
> Plan: `docs/superpowers/plans/2026-06-12-library-reader-ux-overhaul.md`
> Codex work log: `docs/superpowers/codex-work-process.txt`
> Branch: `feat/mvp-implementation`
> For the next session: copy the **Takeover prompt** at the bottom of this file into a fresh Claude Code session, or just say "continue from docs/superpowers/keep-on-report.md".

## TL;DR

Codex executed the plan with subagent-driven development, finished **Tasks 1–4 (committed + spec/quality reviewed)**, produced a **complete, verified, but UNCOMMITTED Task 5 patch** in the working tree, then hit its usage limit. The user had instructed Codex to stop after Task 5 and write a handoff — the handoff was never written; this report replaces it.

**Tree state right now (independently re-verified on 2026-06-12 19:17 by this session, not taken from the Codex log):**

- `./scripts/verify.sh` → **PASS** (app builds, ChapterlyCore **91/91 tests pass**) *with the uncommitted Task 5 patch applied*.
- Tasks 6, 7, 8, 9 not started.
- The plan file's `- [ ]` checkboxes were never ticked (Codex tracked tasks externally). **Git history is the source of truth, not the checkboxes.**

## Completed work (committed)

| Task | Commits | Review gates |
|---|---|---|
| T1 Bookmark field + store toggle | `578e026` + `46077b4` (test hardening) | spec PASS, quality PASS after fix |
| T2 Line-height CSS variable + script | `f1c3a70` + `ffc8d96` (locale fix) | spec PASS, quality PASS after fix |
| T3 Library TOC bookmark replaces progress % | `f00821d` | spec PASS, quality PASS |
| T4 PatreonWebView tap/back-swipe hooks | `9559866` | spec PASS, quality PASS |

The two follow-up commits came out of the quality-review gates:

- `46077b4` — T1's bookmark test originally re-fetched through the same SwiftData `ModelContext`, which would pass even if `context.save()` were removed. The test now uses a temporary **on-disk** store and reloads through a fresh `LibraryStore`/container to prove real persistence. (Pattern lives in `ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift`.)
- `ffc8d96` — T2's `String(format: "%.2f", …)` was locale-sensitive (comma decimals in some locales would emit invalid CSS). Now uses `Locale(identifier: "en_US_POSIX")` plus a regression test asserting the exact dot-decimal JS string.

## Task 5 — DONE BUT UNCOMMITTED (first thing to finish)

The working tree contains the full Task 5 patch. This session compared every file against the plan: **the three reader files match the plan's specified contents exactly**, plus one deliberate plan correction (below).

Dirty files and their disposition:

| File | State | Action |
|---|---|---|
| `App/Features/Reader/ReaderPreferences.swift` | modified — matches plan (drop `readerModeEnabled`, add clamped `lineSpacing`) | commit |
| `App/Features/Reader/ReaderPreferencesPanel.swift` | **new** — matches plan (2×2 capsule grid) | commit |
| `App/Features/Reader/ReaderView.swift` | modified — matches plan (immersive chrome, bookmark, swipe-to-leave, panel, open-at-top) | commit |
| `App/Features/Settings/SettingsView.swift` | modified — one line removed (see plan correction) | **commit with T5** |
| `build/xcodebuild.log` | build artifact, churns on every verify.sh | never stage |
| `WIKI_SYNC.md` | stale 2026-06-11 handoff artifact, unrelated | never stage |
| `docs/superpowers/codex-work-process.txt`, `docs/superpowers/plans/…overhaul.md`, this report | docs/artifacts | leave; user decides if/when to commit |

**Plan correction discovered by Codex (keep!):** the plan's T5 file list missed that `SettingsView.swift` referenced the removed `prefs.readerModeEnabled` (`Toggle("Reader mode by default", …)`). The toggle line was removed as a compile-preserving fix; the font-size Stepper stays. Consequences:

1. The T5 commit must include `App/Features/Settings/SettingsView.swift` (the plan's `git add` line lists only the three reader files — add the fourth).
2. T9's documentation proposal should also mention the removed Settings toggle.
3. T7 step 4.3 (the three Settings copy strings: "reading progress" → "bookmarks") is **still pending** — only the toggle was touched.

What remains for T5 (plan steps 4–6):

1. ~~verify.sh~~ — already done (PASS, this session).
2. Commit: `git add App/Features/Reader/ReaderPreferences.swift App/Features/Reader/ReaderPreferencesPanel.swift App/Features/Reader/ReaderView.swift App/Features/Settings/SettingsView.swift` → `git commit -m "feat(reader): immersive chrome, bookmark toggle, swipe-to-leave, full-width preferences panel"`
3. Review gates (spec + quality) per subagent-driven-development, if continuing that workflow.
4. Manual simulator check (plan T5 step 5) — needs the user; can be folded into the T8 UX sweep instead of blocking now.

## Remaining tasks (not started)

- **T6** "Check for new chapters": add `env.refresher` WebViewModel + `refreshCollection` + `CollectionRefreshOutcome` to `App/AppEnvironment.swift`; swap TOC toolbar `+` for refresh button and delete add-sheet in `CollectionTOCView.swift`; update banner copy in `WebCollectionBanner.swift`; delete `addManualChapter` from `LibraryStore.swift` and replace its test with `testRenameAndDelete`.
- **T7** Remove reading-progress end-to-end (biggest task, one commit): delete `ReaderProgressPolicy.swift` + `ProgressTracker.js`; strip progress from `Payloads/PayloadValidator/ScriptMessageRouter/JSAssets/LibraryStore/Models/ReaderStyler` + tests; remove app wiring (`WebViewModel` user script, `AppEnvironment.onProgress`); Settings copy strings; SmokeAutopilot progress steps → bookmark steps (`bookmark_save`, `bookmark_restore`, `reader_top`); `scripts/smoke-auto.sh` `EXPECTED_STEPS=7` → `8` (line 18; current value re-confirmed as 7).
- **T8** Final verification: `./scripts/verify.sh`, then user-assisted `./scripts/smoke-auto.sh` (needs simulator logged into Patreon + `.env` `SMOKE_TEST_URL`), then manual UX sweep.
- **T9** Docs: **USER CONFIRMATION GATE.** Propose README.md + CLAUDE.md changes, edit only after explicit approval (user's global CLAUDE.md rule). Include the Settings-toggle removal in the proposal.

## Process learnings from the Codex run (why it got stuck)

Useful if the next session also uses subagent-driven development:

1. **Review/fix subagents repeatedly wedged without reporting** — even tiny read-only spec checks. T1's spec review took 3 dispatch attempts; several fix workers stalled mid-edit. The Codex-side fix that worked: close the stalled agent, re-dispatch with an ultra-narrow output contract ("Return exactly one line: PASS or FAIL: <file:line reason>").
2. **Recovery pattern that worked:** when a worker went silent, check the worktree (`git status` / `git diff`) for a partial patch; if the patch is complete and scoped, verify locally and commit directly instead of waiting. Both T2 and T5 landed this way.
3. **Agent-pool thread limit** hit at T4 dispatch — close completed agents before creating new ones.
4. These stalls were Codex-runtime-specific; Claude Code's Task tool is synchronous, so the same workflow should run smoother here. Still, keep review prompts small and PASS/FAIL-shaped.

## Hard constraints (carry over, from project CLAUDE.md + plan)

- **Never** erase/reset the simulator or uninstall the app — the user's manual Patreon login must survive. Never automate Patreon login; never read `.env` or print secrets/cookies/tokens.
- `cd ChapterlyCore && swift test` = fast core check; `./scripts/verify.sh` = full check (minutes). After smoke failures read `build/smoke/auto-report.md` + logs **before** changing code.
- No `xcodegen generate` needed unless the build complains about missing files (XcodeGen globs `App/`; `ReaderPreferencesPanel.swift` is already picked up — verify.sh proved it).
- `orderIndex 0` = newest post; story order = descending `orderIndex`. Reader distinguishes library chapters (`foreignPageTitle == nil`, CSS applied) vs foreign pages (CSS stripped) — keep intact.
- UI copy mixes English with zh-TW (上一章/下一章); code/comments in English.
- README.md / CLAUDE.md: propose first, edit only after user confirmation.

