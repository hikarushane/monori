# ADR-0009: AsianFanfics 2026 Redesign Selectors

## Status
Accepted

## Date
2026-08-15

## Context
Importing any AsianFanfics story showed the alert `未找到章節` / `此頁面未找到章節連結。請確認收藏頁面已完全載入後再試一次。` — every story, no exceptions.

Reproduced against the live site, logged out, at desktop 1280px and mobile 375px (2026-08-15): AsianFanfics shipped a Tailwind front-end rewrite (`body.goth-shell`). Every selector the adapter relied on is gone:

| Selector | Old role | Live result |
|---|---|---|
| `#story-title` | story title | absent |
| `.widget--chapters` | chapter list widget | 0 nodes |
| `select[name="chapter-nav"]` | chapter dropdown | 0 nodes |
| `main.primary` | content root | 0 nodes |
| `#user-submitted-body` | chapter body | absent |

Confirmed site-wide rather than per-story or per-skin by checking a second, unrelated story by a different author (`/story/view/1470000`) — same absence of every selector.

The new markup gives the chapter list a stable hook: each table-of-contents row carries `data-toc-chapter` — `"0"` marks the Foreword, `1..N` mark chapters. The TOC is rendered twice, once in the desktop `aside` and once in a mobile `<dialog>`, so a naive scan double-counts every chapter. A client-inserted "▶ Continue" row carries no `data-toc-chapter` at all. Story title and author no longer live at a fixed id; they sit inside the first `<header>` element that contains an `<h1>` (the page has three `<header>` elements — only the story header has an `<h1>`). Chapter body moved to `#bodyText`. Chapter URLs also gained a slug segment: `/story/view/1754805/3/paper-ghosts-ipsum`.

## Decision
Anchor extraction on `data-toc-chapter` for the chapter list and on "the first `<header>` containing an `<h1>`" for story title/author, instead of on Tailwind utility classes, which change with every restyle:

- Chapter rows are collected by `[data-toc-chapter]`, **deduped by chapter number** (the desktop `aside` and mobile `dialog` both render the full TOC).
- `data-toc-chapter="0"` (Foreword) is treated as metadata, not a chapter — `if (n === 0) continue;`.
- The "▶ Continue" row has no `data-toc-chapter` attribute, so it is excluded by construction rather than by name/text matching.
- Story title and author are read from `document.querySelectorAll('header')`, filtered to the first one containing an `<h1>`.
- The reader stylesheet targets `#bodyText` for chapter content, with the `aside` hide rule scoped so it doesn't also blank the desktop TOC panel when it's meant to stay visible.
- Browse-mode ad/promo slots introduced by the redesign are hidden separately (content rule list), not folded into the chapter-extraction logic.

Shipped across nine commits:

| Commit | Summary |
|---|---|
| `07e5034` | test(aff): fixtures for the redesign |
| `4d0e72a` | fix(aff): extract chapters from the redesigned `data-toc` table of contents |
| `dc6edc9` | fix(test): assert non-empty chapter list before vacuous checks in AFF extraction tests |
| `fca6146` | fix(test): replace crash-prone subscript with XCTUnwrap in AFF fallback test |
| `8f357a2` | fix(aff): read story title and author from the redesigned header |
| `8eb04bc` | test(aff): pin canonical URL handling for slug-suffixed chapter paths |
| `8fefe20` | fix(aff): retarget the reader stylesheet at `#bodyText` in the new markup |
| `392accf` | fix(aff): whitelist asides inside `#bodyText` and `#comments` |
| `028ff85` | fix(aff): hide the redesigned ad and promo slots in browse mode |

## Alternatives Considered

### Parse the mobile `<dialog>` TOC only
- Pros: only one copy to scan, no dedupe needed
- Cons: it is `<dialog>` content and may be lazily populated (or not populated at all until the user opens it) in a future release; the desktop `aside` copy is always present in the initial DOM
- Rejected: dedupe-by-chapter-number is a few lines and removes the dependency on drawer-open timing entirely

### Select titles on `span.truncate`
- Pros: matches the visible title text directly, no header-walking
- Cons: `truncate` is a Tailwind utility class with no semantic meaning — any restyle that swaps the truncation approach (a different class, inline `text-overflow`, a wrapper `<div>`) silently breaks it again, the exact failure mode this ADR exists to avoid
- Rejected: "first `<header>` with an `<h1>`" relies on HTML semantics AFF has no reason to change independent of a visual restyle

## Consequences
- A link-scan fallback still covers stories that ship no TOC at all; if AFF ever drops the `data-toc-*` attributes, import keeps working through that fallback, just with weaker (link-text-derived) titles instead of failing outright.
- The reader stylesheet is now keyed to `#bodyText`, which is also the id AFF's own reader-font `<style>` block targets — the site itself has an incentive to keep that id stable, so it is less likely to churn than a Tailwind class was.
- **Known cosmetic gap:** in the reader, the page background is AFF's own dark navy from the `div.relative.z-10 … dark:bg-[#0f172a]` wrapper rather than the ruleset's `#1c1b19`, because `AFFReaderRuleset.css` only paints `body` and the wrapper sits on top of it and covers it. Text stays legible; not fixed in this plan.
- Verified with `./scripts/verify.sh` (`** BUILD SUCCEEDED **`, 279 XCTest + 11 swift-testing tests, 0 failures) and end-to-end in the iOS Simulator against the live site: the banner shows the real title "Paper Ghosts (Ipsum)", import reports `已匯入 5 個章節`, the library lists exactly Chapter 1–5 in order with no Foreword and no Continue row, and Chapter 2 opens in the reader as clean text with no site nav, footer, floating bottom bar, or ads. Screenshots: `build/smoke/ui/step-245-11-import-tapped.png`, `step-248-14-toc-open.png`, `step-249-15-chapter2-reader.png`.
- The next time AsianFanfics restyles, re-verify against the live DOM before touching selectors again — see the `data-toc-*` note added to `MEMORY.md`.
