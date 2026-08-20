# ADR-0010: Reader Dark Mode Background Override Strategy

## Status
Accepted

## Date
2026-08-20

## Context
In dark mode, the reader showed three different failure modes depending on source, while light mode was correct for all five:

| Source | Symptom |
|---|---|
| AO3 / Google Docs (stored HTML) | Black overlay — body text rendered black-on-black, effectively invisible |
| Patreon / AsianFanfics (AFF) | Background stayed the site's own native dark color instead of Monori's Sumi Ink `#1C1B19` |
| Vocus | Correct |

A prior fix attempt — adding `.preferredColorScheme(env.appPrefs.appearance.colorScheme)` to the reader's `fullScreenCover` (SwiftUI level) — did not resolve any of the above. That confirmed the bug was inside the WKWebView content (CSS/DOM), not in native color-scheme propagation.

Diagnostic JS was injected into `applyReaderTreatment()` after CSS injection to capture, per chapter open:
```js
var dm = window.matchMedia('(prefers-color-scheme: dark)').matches;
var cs = getComputedStyle(document.documentElement).colorScheme;
var bg = getComputedStyle(document.body).backgroundColor;
var tc = getComputedStyle(document.body).color;
```

Results across all five sources: `darkMatch=true`, `colorScheme=light dark`, `bodyBg=rgb(28, 27, 25)` (`#1C1B19`, correct) in every case. Two sources showed `bodyColor=rgb(0, 0, 0)` (AO3/Google Docs — the black-overlay symptom); the others showed a light color. This eliminated the two most obvious suspects — the `prefers-color-scheme` media query and the `body` background rule — and isolated the real fault to two separate, lower-level causes:

1. **Text color** (AO3, Google Docs): `ReaderStyler.wrappedDocument()` (used for Google Docs stored HTML) set `* { color: inherit !important }`. This selector also matches `<html>`, which has no explicit `color`, so it resolves to the UA-stylesheet initial value (black). The dark-mode override `body { color: #F2F0ED }` had no `!important`, so it lost to the `!important` (but wrongly-scoped) rule above it. AO3 shares `ReaderRuleset.css` with Patreon, whose dark-mode text-color selectors were Patreon-specific and didn't cover AO3's DOM, producing the same black-text symptom by a parallel path.

2. **Background on intermediate containers** (Patreon, AFF): the `body` background was correct, but DOM elements between `body` and the article content kept the host site's own dark background, which visually sits on top of and hides `body`'s background. `VocusReaderRuleset.css` was the only ruleset that already handled this, via:
   ```css
   body > *, body > * > *, body > * > * > *,
   body > * > * > * > *, body > * > * > * > * > *,
   body > * > * > * > * > * > * {
     background-color: inherit !important;
   }
   ```
   This ADR's first fix attempt applied that identical 6-level cascade to `ReaderRuleset.css` (Patreon) and `AFFReaderRuleset.css`. AFF continued to work correctly. Patreon broke completely — the article rendered as a blank page in both light and dark mode, not just wrong-colored.

## Decision
Split the background-override strategy by page rendering model instead of using one cascade for every URL-loaded source:

- **Server-rendered pages (AFF, Vocus)**: keep the CSS `body > * ... !important` cascade, 6 levels deep, matching the existing Vocus pattern. Added the same cascade to `AFFReaderRuleset.css`.
- **SPA pages (Patreon)**: replace the CSS cascade with a JS routine, `clearAncestorBg()`, added to `ReaderStyler.injectionScript()`. It locates the actual content container (`[data-tag="post-content"]`, `.patreon-post-content`, or `article`, in that order) and walks *only that element's ancestor chain* up to `document.documentElement`, clearing `background-color` on each ancestor. No other DOM node is touched.
- **Text color** (`wrappedDocument()`): narrowed `* { color: inherit !important }` to `body * { color: inherit !important }` so `<html>` is no longer part of the match, and added `!important` to the dark-mode `body { color: #F2F0ED }` override so it wins outright rather than depending on `<html>` resolving correctly.
- **`ReaderRuleset.css` / `AFFReaderRuleset.css`**: added `:root { color-scheme: light dark }` where missing, and `!important` on the dark-mode `body { color }` rule in both.

## Alternatives Considered

### SwiftUI-level `.preferredColorScheme` only
- Pros: single native call, no CSS/JS changes needed
- Cons: only affects native chrome and `overrideUserInterfaceStyle` (which drives the `prefers-color-scheme` media query) — it cannot reach specificity/`!important` conflicts or sibling-element background colors already inside the loaded page's DOM
- Rejected: tried in a prior session; diagnostic evidence in this session confirmed `prefers-color-scheme` was already matching correctly everywhere, so the native layer was not the fault

### Uniform CSS cascade (`body > * { background-color: inherit !important }`, N levels) on every URL-loaded source
- Pros: one code path, already proven correct for Vocus and (in testing) AFF
- Cons: on Patreon specifically, forcing `background-color` on every intermediate container broke the page outright (blank, not just miscolored) — Patreon's React-rendered DOM depends on styling of some intermediate containers in a way a blanket override disrupts
- Rejected: the failure mode (total content loss) is worse than the bug being fixed; a source-specific strategy was required instead of a single shared ruleset change

## Consequences
- Resolves the "known cosmetic gap" flagged in [ADR-0009](0009-asianfanfics-2026-redesign-selectors.md)'s Consequences section, where AFF's dark-mode background was noted as showing the site's own dark navy instead of `#1C1B19` — the new 6-level cascade in `AFFReaderRuleset.css` fixes this directly.
- Reader dark-mode background handling is no longer uniform across sources: server-rendered sources use a CSS cascade, SPA sources use a JS ancestor walk. Any future source added to the reader needs this classification made explicitly rather than copying whichever ruleset is closest — see the pattern captured in `MEMORY.md`'s architecture-decisions table and the cross-project note in `WIKI_SYNC.md`.
- `clearAncestorBg()` re-runs once via `setTimeout(clearAncestorBg, 1500)` in addition to the immediate call, mirroring the retry pattern already used by Vocus's `cleanVocusChrome()`, to cover containers that Patreon's SPA renders in after the initial injection.
- Verified with `xcodebuild build` (`** BUILD SUCCEEDED **`) and `swift test` (13/13 passed) in `MonoriCore`, plus manual verification in the iOS Simulator across all five sources (Patreon, AO3, Google Docs, AFF, Vocus) in both light and dark mode, confirmed by the user.
- Diagnostic JS added during investigation was removed from `ReaderView.swift` after the fix was confirmed; it is not part of the shipped code path.
