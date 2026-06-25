# Vocus (方格子) Reading Source

> Date: 2026-06-26
> Scope: Vocus as fourth reading source, web-based reader model
> Prerequisite: Multi-source infrastructure from AO3 spec (2026-06-25)
> ADR: docs/decisions/0003-multi-source-architecture-and-ao3.md

## Context

Monori supports Patreon (web-based), Google Docs (local HTML), and AO3 (local
HTML). This spec adds vocus (方格子) as the fourth source using the web-based
reader model (like Patreon).

### Terms of Service Constraint

Vocus ToS explicitly prohibits "以程式重製" (programmatic reproduction). Local
HTML storage is not permitted. The integration uses web-based reading only:
articles load in WKWebView from vocus.cc with reader CSS injected.

### Vocus Platform Model (2025–2026)

Vocus transitioned from "出版專題" (publications) to a "沙龍" (salon) model:

| Concept | Old URL | Current URL |
|---------|---------|-------------|
| Publication home | `vocus.cc/{slug}/home` | `vocus.cc/salon/{salonId}/room/{roomSlug}` |
| Publication intro | `vocus.cc/{slug}/introduce` | `vocus.cc/salon/{salonId}/about` |
| Article | `vocus.cc/article/{hexId}` | same |
| Subscription | — | `vocus.cc/salon/{salonId}/plans/content` |

Old slug URLs (`vocus.cc/{slug}/home`) 302-redirect to the new salon/room URL.
No special handling needed.

A **salon** is a creator's space (≈ Patreon creator page). A **room** is a
themed article collection within a salon (≈ Patreon collection / AO3 work).
One salon can have multiple rooms.

### Article IDs

Vocus article IDs are 24-character hex strings (MongoDB ObjectId format),
e.g. `67ca7699fd897800017f312c`.

### API (Reference Only — Not Used for Import)

Vocus has an undocumented public API at `api.vocus.cc` (used by RSSHub for
years). We chose DOM scraping over API for import to preserve user auth state
and handle paid content visibility. The API is documented here for reference:

- `GET api.vocus.cc/api/publication/{slug}` → `{ data: { publicationData: { _id, title, abstract } } }`
- `GET api.vocus.cc/api/articles?publicationId={_id}` → `{ data: { articles: [...] } }`
- `GET api.vocus.cc/api/article/{articleId}` → `{ data: { article: { content, tags, ... } } }`

## 1. NavigationPolicy

Allow `vocus.cc` and `*.vocus.cc` in WKWebView:

```swift
// In NavigationPolicy.decide(url:isMainFrame:)
case host.hasSuffix("vocus.cc"):
    return .allowInWebView
```

This covers `vocus.cc`, `www.vocus.cc`, and `api.vocus.cc`.

## 2. URLNormalizer

New methods following the AO3 pattern:

| Method | Input | Output |
|--------|-------|--------|
| `isVocusRoomURL(_:)` | `vocus.cc/salon/{id}/room/{slug}` | `true` |
| `isVocusRoomURL(_:)` | `vocus.cc/salon/{id}/room/{slug}/{category}` | `true` (category suffix ignored) |
| `isVocusRoomURL(_:)` | `vocus.cc/salon/{id}` | `false` (salon home, not room) |
| `vocusRoomSlug(_:)` | room URL | `"bass"` or `nil` |
| `vocusSalonID(_:)` | room or salon URL | `"65a4a22bfd89780001e7867a"` or `nil` |
| `isVocusArticleURL(_:)` | `vocus.cc/article/{hexId}` | `true` |
| `vocusArticleID(_:)` | article URL | `"67ca7699fd897800017f312c"` or `nil` |
| `canonicalVocusRoomURL(_:)` | any room URL variant | `https://vocus.cc/salon/{salonId}/room/{slug}` (strips category) |

URL path parsing via path component splitting (same approach as AO3):
- Room: path components `["salon", salonId, "room", roomSlug, ...]`
- Article: path components `["article", hexId]`
- Validation: salonId and articleId are 24-char hex; roomSlug is non-empty

## 3. Detection JS (VocusRoomDetect.js)

Injected when `URLNormalizer.isVocusRoomURL(url)` is true, after page load.

### Trigger Conditions (all must hold)

1. URL pathname matches `/salon/{salonId}/room/{roomSlug}` (with optional
   category suffix)
2. Page contains at least one `a[href^="/article/"]` link

### Extracted Data

```javascript
window.webkit.messageHandlers.monoriCollectionLink.postMessage({
    collectionName: roomTitle,    // from page heading or tab text
    collectionURL:  location.href,
    creatorName:    salonName     // from salon header
});
```

### Room Title Extraction Strategy

The room title appears in multiple places:
1. The active nav tab text (most reliable — it's the selected tab)
2. The heading inside the room info card
3. The `<title>` tag: `"{roomTitle}｜方格子 vocus"`

Prefer: active nav tab text → `<title>` tag parse → fallback to roomSlug.

### Salon Name Extraction Strategy

The salon name appears in the top header. Extract from the header text or from
the page `<title>` on the salon home page. On room pages, the header still
shows the salon name.

### Injection Timing

Same as AO3: `WebViewModel` checks URL in `webView(_:didFinish:)`. If
`isVocusRoomURL`, inject `VocusRoomDetect.js`. Uses the existing
`monoriCollectionLink` message handler — no new handler needed.

## 4. Import JS (VocusRoomImport.js)

Executed via `callAsyncJavaScript` when user taps the import banner.

### Flow

1. Collect all visible `a[href^="/article/"]` links
2. For each link, extract: title text, URL, excerpt (adjacent paragraph),
   creator name, DOM order index
3. Scroll to page bottom (`window.scrollTo(0, document.body.scrollHeight)`)
4. Wait 1.5s for infinite scroll to load new content
5. Collect new links
6. Repeat steps 3–5 until no new links appear (two consecutive scrolls with
   same count → done)
7. Cap at 10 scroll attempts to prevent infinite loops
8. Deduplicate by article ID (extracted from href)
9. Post each article via `monoriImport` message handler:

```javascript
window.webkit.messageHandlers.monoriImport.postMessage({
    title:          articleTitle,
    url:            "https://vocus.cc" + articleHref,
    excerpt:        excerptText,
    creatorName:    authorName,
    collectionName: roomTitle,
    collectionURL:  location.href,
    domOrder:       index
});
```

### DOM Selectors

- Article links: `a[href^="/article/"]` (stable — URL pattern won't change)
- Title: text content of the link or its heading child
- Excerpt: sibling/child paragraph text near the title
- Author: author name element near each article card
- These are positional/structural selectors, not class-name dependent

### Differences from Patreon CollectionImport.js

| Aspect | Patreon | Vocus |
|--------|---------|-------|
| Loading mechanism | "Load more" button click | Infinite scroll |
| Completion signal | Button disappears | No new links after scroll |
| Article link pattern | `a[href*="/posts/"]` | `a[href^="/article/"]` |
| Max attempts | Until button gone | 10 scroll attempts |

### Progress Reporting

Same pattern as AO3 import: post intermediate counts so Swift can show
"Importing X of Y…" progress. The total is unknown upfront (infinite scroll),
so show "Found N articles…" during scroll phase, then "Importing…" during
the post phase.

## 5. Reader CSS (VocusReaderRuleset.css)

Injected on article pages (`isVocusArticleURL`) when reader mode activates.

### Elements Hidden

| Target | Selector Strategy |
|--------|-------------------|
| Salon header + nav tabs | First `position:fixed; top:0` container |
| Ads | `iframe`, `[data-type="AdaptiveColorCard"]` |
| QR / app download popup | Fixed-position bottom-right overlay |
| Bottom sharing toolbar | Fixed-position bottom bar with social icons |
| Next-article recommendations | `.next-article-col` |
| Comment section | Content after article body container |
| Table of contents sidebar | `.table-of-contents` |
| "為什麼會看到廣告" prompt | Block containing ad-explanation text |

### Elements Preserved

- `h1` article title
- Author/date metadata (`.articleHeader`, `.article-info`)
- Article body (`.editor-content-block`, `.lexical-web-theme`)
- Paragraphs (`.lexical__paragraph`)
- Images (`.lexical__image`)

### Typography

Do NOT override vocus native fonts. Vocus uses clean typography that works
well as-is. Only inject:

- `--monori-font-size` CSS variable (for app font-size preference)
- `--monori-line-height` CSS variable (for app line-height preference)

Apply these to `.editor-content-block` so user preferences take effect without
fighting vocus's own styles.

### Selector Stability Notes

Vocus uses styled-components (`sc-*` hashed class names) — these are NOT
stable and must not be used in selectors. Stable selectors:

- `.editor-content-block` — article content wrapper
- `.lexical-web-theme` — Lexical editor theme
- `.lexical__paragraph`, `.lexical__image` — content elements
- `.table-of-contents` — TOC sidebar
- `.next-article-col` — recommendations
- `.article-info` — metadata block
- `[data-type="AdaptiveColorCard"]` — ad cards
- `a[href^="/article/"]` — article links

When a selector targets a dynamic-class element, use structural/positional
selectors (e.g., `body > div > div:first-child` for the top fixed header).

## 6. Swift Integration

### SourceRegistry

```swift
// Add to SourceRegistry.all
static let all: [SourceProvider] = [patreon, googleDrive, ao3, vocus]

static let vocus = SourceProvider(
    kind: .vocus,
    displayName: "Vocus",
    startURL: URL(string: "https://vocus.cc")!
)
```

Remove the placeholder fallback in `provider(for:)` that returns `.patreon`
for `.vocus`.

### AppEnvironment

Add lazy `vocusBrowse: WebViewModel` following `ao3Browse` pattern:

```swift
@ObservationIgnored private var _vocusBrowse: WebViewModel?
var vocusBrowse: WebViewModel {
    if _vocusBrowse == nil { let m = WebViewModel(); wire(m); _vocusBrowse = m }
    return _vocusBrowse!
}
```

### WebViewModel Extensions

- `isOnVocusRoomPage` → `URLNormalizer.isVocusRoomURL(currentURL)`
- `runVocusRoomDetect()` → inject `VocusRoomDetect.js`
- `runVocusRoomImport()` async → `callAsyncJavaScript(VocusRoomImport.js)`

Detection runs in `webView(_:didFinish:)` when on a vocus room page.

### Import Result

```swift
ImportedCollection(
    sourceURLString: canonicalRoomURL,
    title: roomTitle,
    creatorName: salonName,
    sourceKind: .vocus,
    chapters: articles.map { ImportedChapter(
        title: $0.title,
        urlString: "https://vocus.cc/article/\($0.id)",
        orderIndex: $0.domOrder,
        contentHTML: nil  // web-based, no local storage per ToS
    )}
)
```

### BrowseView

`SourceRegistry.all` already drives the picker via `ForEach`. Adding `.vocus`
to `all` makes it appear automatically. The `activeModel` computed property
needs a new case:

```swift
case .vocus: env.vocusBrowse
```

### MonoriIcons

Replace the placeholder circle stroke for `.vocus` with a custom geometric
glyph. Follow existing pattern in `MonoriIcons.swift` — all source icons are
custom `Shape` structs, no SF Symbols. Use a square with rounded corners
(方格子 = "grid/square") as the base motif.

### Refresher

`sourceKind == .vocus` skips collection refresh (already handled by
`5793a13` — the skip-refresh logic applies to all non-Patreon sources).

## 7. Testing Strategy

### Unit Tests (verify.sh)

| Test | Coverage |
|------|----------|
| `URLNormalizerVocusTests` | `isVocusRoomURL` (room, room+category, salon-home=false, article=false), `vocusRoomSlug`, `vocusSalonID`, `isVocusArticleURL`, `vocusArticleID`, `canonicalVocusRoomURL` |
| `NavigationPolicyVocusTests` | `vocus.cc` → `.allowInWebView`, `api.vocus.cc` → `.allowInWebView`, `random.com` → not affected |
| `VocusRoomDetectTests` | Fixture HTML with room page structure → JS extracts collectionName + collectionURL |
| `VocusRoomImportTests` | Fixture HTML with article cards → JS extracts title/url/domOrder for each |
| `SourceKindVocusTests` | `.vocus` codable roundtrip (already exists), provider lookup |

### Fixture HTML

Source: manually curated from real vocus room and article pages. Keep:
- `a[href^="/article/"]` structure with realistic hrefs
- `.editor-content-block` / `.lexical__paragraph` structure
- Nav tabs and salon header structure

Remove: personal data, actual article content, images (use placeholder text).

### Manual Smoke Tests (require vocus login)

1. Browse → select Vocus → vocus.cc loads
2. Navigate to a salon room → import banner appears
3. Tap import → articles scraped with scroll-to-load → chapter list populated
4. Open a chapter → article loads in reader view
5. Reader CSS: ads hidden, header hidden, content readable
6. Font size / line height preferences apply
7. Paid article (subscribed): title visible, content loads
8. Paid article (not subscribed): title visible, paywall shown by vocus

### Edge Cases

- Empty room (0 articles) → banner appears but import finds 0, show message
- Room with only paid articles (unsubscribed) → titles still visible in DOM
- 100+ articles → infinite scroll completes within 10 attempts
- URL-encoded Chinese category in room URL → `isVocusRoomURL` still matches
- Salon home (`/salon/{id}` without `/room/`) → no banner (not a room)
- Old slug URL (`/bass/home`) → vocus redirects, detection works on final URL

## 8. Files Changed (Estimated)

| Layer | File | Change |
|-------|------|--------|
| MonoriCore | `SourceKind.swift` | Add vocus to `SourceRegistry.all`, wire provider, remove placeholder |
| MonoriCore | `NavigationPolicy.swift` | Allow `vocus.cc` |
| MonoriCore | `URLNormalizer.swift` | Add vocus room/article URL parsing methods |
| MonoriCore | `ReaderStyler.swift` | Load `VocusReaderRuleset.css` for vocus articles |
| Assets | `VocusRoomDetect.js` | New: room detection script |
| Assets | `VocusRoomImport.js` | New: article list scraping with infinite scroll |
| Assets | `VocusReaderRuleset.css` | New: reader mode CSS for vocus articles |
| App | `AppEnvironment.swift` | Add lazy `vocusBrowse`, wire detection + import callbacks |
| App | `WebViewModel.swift` | Add `isOnVocusRoomPage`, detection/import methods |
| App | `BrowseView.swift` | Add `.vocus` case to `activeModel` switch |
| App | `MonoriIcons.swift` | Replace placeholder glyph |
| Tests | `URLNormalizerVocusTests.swift` | New: URL parsing tests |
| Tests | `NavigationPolicyVocusTests.swift` | New: allowlist tests |
| Tests | `VocusRoomDetectTests.swift` | New: detection JS tests |
| Tests | `VocusRoomImportTests.swift` | New: import JS tests |
| Tests | Fixture HTML files | New: room page + article page fixtures |
