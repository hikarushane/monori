# Chapterly — Design Spec

Date: 2026-06-10
Status: Approved in brainstorming; pending written-spec review

## 1. Product definition

Chapterly is an open-source, sideloaded, local-only iOS reading shell for a user's own Patreon session. The user logs into patreon.com inside a WKWebView with their own account. Patreon remains the source of truth and enforces all access control. Chapterly adds a calm reading layer on top: collection-based chapter navigation, distraction-removal CSS, typography adjustment, and local reading progress.

Chapterly is not a Patreon client, not a Patreon API consumer, not a content mirror, and not an App Store product.

### What changed from the draft brief

- Name is **Chapterly** (draft body's "Shelfway" is dropped).
- Distribution is **sideloaded IPA** (personal use, self + others), open-source. App Store guidelines 4.2 / 5.2.2 are not constraints.
- **No Patreon OAuth, no Patreon API, no backend, no client_secret** in MVP. The draft's feasibility research concluded the patron-token API path is almost certainly infeasible: Patreon API v2 posts endpoints (`/campaigns/{id}/posts`, `/posts/{id}`) are creator-scoped; a patron token cannot fetch post lists or content of supported campaigns. OAuth token exchange would also require a client_secret and therefore a backend broker. The entire API path is cut.
- Chapter ordering is **collection-based, not title-number-based**. No regex chapter detection. Titles like "5 脣瓣" are display-only; order comes from the Patreon Collection page DOM order plus manual correction.
- MVP screens reduced from 9 to 6. Memberships, API-limitation, and access-revoked screens are deleted (no API → no such states; revoked access simply shows Patreon's own locked page through the webview).

### Future option (explicitly out of MVP)

If a future feature genuinely needs the Patreon API, add a tiny stateless Cloudflare Worker token broker for `authorization_code` and `refresh_token` exchange only. The broker must never store or proxy Patreon content. Never embed a client_secret in the app binary.

## 2. Hard rules

Allowed:

- Local WKWebView reading cleanup (CSS-based distraction removal)
- Local typography adjustment
- Local chapter URL map (collection-based)
- Local previous/next navigation
- Local reading progress and bookmarks
- Local table of contents built from the currently visible page only
- Open-source implementation; no backend content storage

Forbidden:

- Cookie scraping; reading or exporting session cookies
- Intercepting Patreon network responses
- Calling Patreon internal (or official) APIs in MVP
- Storing full HTML or full post text
- Offline paid-content reading; paid-content export
- Cross-user content database; backend sync of paid content
- AI summaries of paid content
- Automatic crawling of pages the user has not loaded
- Patreon branding misuse (no logo, no implied partnership)

## 3. Architecture

SwiftUI, iOS 17 minimum, MVVM, async/await, SwiftData. No third-party networking; the only network activity is the WKWebView talking to patreon.com.

```
Chapterly/
  App/                 ChapterlyApp, root tab view
  Browser/             WebViewContainer, navigation state, script message routing
  Importer/            CollectionImporter (JS + Swift sides), DOM fixtures for tests
  Reader/              ReaderStyler (CSS ruleset), ReaderChromeBars, ProgressTracker
  Library/             Collections list, chapter TOC, map editing
  Settings/            Preferences, clear-data, about/license
  Persistence/         SwiftData models + stores
  DesignSystem/        Tokens + shared components
  Docs/                COMPLIANCE.md, this spec
```

### 3.1 Browse tab

A WKWebView using the default persistent `WKWebsiteDataStore`. The Patreon login session lives entirely inside webview storage; the app never reads, copies, or exports it. Login is the normal patreon.com login page.

### 3.2 Reader

The same WKWebView navigated to a chapter URL from the local map, plus:

- **ReaderStyler**: a `WKUserScript` injecting a CSS ruleset that hides Patreon chrome (nav, sidebars, comments, feed elements) and applies typography preferences (font size, serif body, line height). The ruleset ships as a bundled, human-editable file (not hardcoded selectors) so Patreon DOM changes are fixed by editing one file. Failure mode is graceful: if selectors stop matching, the user sees the plain Patreon page.
- **Native chrome bars**: Previous Chapter (top), Next Chapter (bottom), chapter title, progress indicator. Prev/next resolve from the local collection map only — never from page content.
- **ProgressTracker**: a JS scroll observer reports scroll percentage per chapter URL via `WKScriptMessageHandler`; saved to SwiftData; restored when the chapter reopens. Accuracy is approximate by design (lazy-loaded images shift layout); accepted.

### 3.3 CollectionImporter

User-triggered only; never automatic crawling.

1. On a Patreon post page, detect whether the visible DOM shows a Collection / series link (e.g. "於作品系列中：【更新中】焚心 The Burning Heart"). If present, offer "Import this collection".
2. The user opens the Collection page in the Browse tab.
3. On tap, injected JS reads the **currently visible** chapter anchors and extracts, per chapter: title, URL, visible date text (if any), DOM order. Plus collection name and collection URL.
4. Results post back through `WKScriptMessageHandler` into SwiftData.
5. Collection pages may lazy-load; the user scrolls to reveal more and taps import again. Re-import merges by URL (no duplicates, preserves manual edits).
6. Base order = DOM order. The user can reverse it (newest-first pages), manually reorder, rename display titles, delete entries, and add missing chapters by URL.
7. No order inference from title text. No requirement that titles contain numbers.
8. Never read the post body. Never store page HTML.

Worked example: current chapter "5 脣瓣" → previous "4 愛", next "6 浴室的紅櫻桃(R18+)", all resolved from the saved map of collection "【更新中】焚心 The Burning Heart".

### 3.4 Data model

```swift
struct LocalCollection: Identifiable, Codable {
    let id: String
    let title: String
    let sourceURL: URL
    let creatorName: String?
    var sortDirection: CollectionSortDirection
    var chapters: [LocalChapter]
}

struct LocalChapter: Identifiable, Codable {
    let id: String
    let title: String
    let url: URL
    let sourceCollectionURL: URL
    var orderIndex: Int
    var visibleDateText: String?
    var readingProgress: Double?
    var lastReadAt: Date?
}

enum CollectionSortDirection: String, Codable {
    case oldestToNewest
    case newestToOldest
}
```

Implemented as SwiftData models mirroring these shapes. User preferences (font size, reader mode on/off) in UserDefaults. Stored data is metadata only — titles, URLs, dates, order, progress. Never post bodies.

### 3.5 Screens (6)

1. **Browse** — webview, login, collection detection banner, import action
2. **Library** — imported collections list
3. **Table of Contents** — chapters of one collection: title, date, progress, last-read marker; edit mode for reorder/rename/delete/add; reverse-order toggle
4. **Reader** — webview + reader CSS + native prev/next bars
5. **Settings** — font size, reader mode toggle, clear all local data, about, license
6. **Empty state** — library with no collections; points user to Browse + import

"Clear all local data" wipes SwiftData and the `WKWebsiteDataStore` (acts as logout). There is no separate token logout because the app holds no tokens.

## 4. Error handling

- Import finds 0 chapters → message + pointer to manual add (selectors likely rotted)
- Collection link not detected on a post page → manual "add current page as chapter" still available
- Offline → webview's error page; library/TOC still browsable (metadata is local)
- Deleted, locked, or revoked-access post → Patreon's own page shows through; no special state needed
- Corrupted local store → offer reset with confirmation

## 5. Design direction

Premium minimalist editorial reading app: Apple Books / Instapaper mood, not a dashboard, not a social feed. Native typography (SF Pro UI, New York for reader-adjacent native text), restrained palette, list-first layout, thin dividers, subtle motion, Dynamic Type, VoiceOver labels, Reduce Motion respected. The draft brief's design-token suggestions and reference-screen workflow (taste-skill: imagegen-frontend-mobile, minimalist-skill) apply at implementation time; DESIGN.md will be produced then.

## 6. Testing

- Unit: importer parsing against saved HTML fixtures (including CJK titles such as "5 脣瓣" and collection labels such as "【更新中】焚心 The Burning Heart"), order/reverse logic, merge-by-URL re-import, progress store round-trip
- Manual smoke: real Patreon account, real collection import, prev/next navigation, progress restore, clear-data wipe
- Fixture HTML must be sanitized: structure only, no real paid post bodies committed to the repo

## 7. Accepted risks

| Risk | Position |
|---|---|
| Patreon DOM changes break reader CSS / importer | Editable ruleset file, graceful degradation, open-source contributions. Accepted. |
| ToS gray zone: client-side restyling of a logged-in page | Comparable to Safari Reader Mode / content blockers: local, personal, no extraction, no redistribution. Lowest-risk interpretation, not zero. Documented in COMPLIANCE.md. |
| Scroll progress approximate | Accepted by design. |
| Sideload signing friction for other users | README documents AltStore/SideStore/dev-cert paths. Not a product problem. |

## 8. Deliverables

SwiftUI MVP project (6 screens), CollectionImporter with tests, ReaderStyler ruleset file, local persistence, COMPLIANCE.md, README (build, sideload, signing, what the app deliberately does not do).
