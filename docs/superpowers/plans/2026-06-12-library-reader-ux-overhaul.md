# Library & Reader UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace manual chapter adding with one-tap auto-import of new chapters, remove the reading-progress feature, add a synced bookmark per chapter (Library list + reader), and rework the reader into an immersive mode (chrome hidden by default, tap-center to reveal, full-width non-dismissing preferences panel with font-size and line-spacing controls, always-on reader mode, left-swipe to leave).

**Architecture:** Pure logic stays in the `ChapterlyCore` Swift package (SwiftData models, `LibraryStore`, `ReaderStyler` JS generators) and is unit-tested with `swift test`. SwiftUI views live in the `App` target and are verified by building plus manual simulator checks. The reader keeps its single shared `WKWebView` (`env.reader`); a third offscreen `WebViewModel` (`env.refresher`) re-runs the existing CollectionImport JS against a collection's source URL to fetch new chapters. The debug-only smoke autopilot swaps its progress steps for bookmark steps.

**Tech Stack:** SwiftUI (iOS 17), SwiftData, WebKit (WKWebView), XcodeGen, XCTest (ChapterlyCore package only).

---

## Context the engineer needs

- **Build/test commands:**
  - Core unit tests only: `cd ChapterlyCore && swift test` (fast, no simulator).
  - Full check (app build + core tests): `./scripts/verify.sh` (from repo root; takes minutes).
  - `project.yml` is NOT touched by this plan — no `xcodegen generate` needed (no files are added to or removed from target *roots*; new/deleted Swift files under `App/` and `ChapterlyCore/Sources/` are picked up automatically because XcodeGen globs the `App` directory and the package manages its own sources). **Exception:** after creating or deleting Swift files, run `xcodegen generate` once anyway if the build complains about missing files — it is cheap and safe.
- **Three `WebViewModel` instances after this plan:** `env.browse` (Browse tab), `env.reader` (reader full-screen cover), `env.refresher` (offscreen, for "check for new chapters"). All share `WKWebsiteDataStore.default()`, so the user's manual Patreon login cookie works in all three. Never log or read those cookies.
- **SwiftData migration:** adding `isBookmarked: Bool = false` and removing `readingProgress`/`lastReadAt` are both lightweight migrations — existing libraries on device survive, old progress data is silently dropped. Do **not** erase the simulator; the user's Patreon login must be preserved (CLAUDE.md rule).
- **Patreon ordering convention:** `orderIndex 0` = newest post (first in Patreon DOM). Story order = descending `orderIndex`. `ChapterMapMerger.merge` already dedupes re-imported chapters by normalized URL — "check for new chapters" relies on that and counts the chapter-count delta.
- **The reader treats two page kinds differently:** library chapters (`foreignPageTitle == nil`, full reader CSS) and "foreign" pages — Patreon pages outside the library reached by tapping links (`foreignPageTitle != nil`, CSS stripped). Keep that distinction intact.
- **User-facing copy** in this app mixes English UI labels with some zh-TW labels (e.g. 上一章/下一章). Follow existing copy style; code/comments in English.

### File map (whole plan)

| File | Action |
|---|---|
| `ChapterlyCore/Sources/ChapterlyCore/Models.swift` | add `isBookmarked` (T1); remove `readingProgress`, `lastReadAt` (T7) |
| `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift` | add `toggleBookmark` (T1); remove `addManualChapter` (T6); remove `setProgress` (T7) |
| `ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift` | add bookmark test (T1); remove manual-add test (T6); remove 3 progress tests (T7) |
| `ChapterlyCore/Sources/ChapterlyCore/Assets/ReaderRuleset.css` | line-height CSS variable (T2) |
| `ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift` | add `lineHeightScript` (T2); remove `restoreScrollScript` + `scrollToTopScript`, fix comment (T7) |
| `ChapterlyCore/Tests/ChapterlyCoreTests/ReaderStylerTests.swift` | add line-height tests (T2); remove scroll-to-top test (T7) |
| `App/Features/Library/CollectionTOCView.swift` | bookmark icon replaces progress % (T3); refresh button replaces add-sheet (T6) |
| `App/WebView/PatreonWebView.swift` | content-tap + back-swipe-override hooks (T4) |
| `App/Features/Reader/ReaderPreferences.swift` | drop `readerModeEnabled`, add `lineSpacing` (T5) |
| `App/Features/Reader/ReaderPreferencesPanel.swift` | **new** — full-width 2×2 controls panel (T5) |
| `App/Features/Reader/ReaderView.swift` | chrome auto-hide, bookmark button, swipe-to-leave, panel, always-on reader mode, open-at-top (T5) |
| `App/AppEnvironment.swift` | `refresher` model + `refreshCollection` (T6); remove progress wiring (T7) |
| `App/Features/Shared/WebCollectionBanner.swift` | update "no chapters found" copy (T6) |
| `App/WebView/WebViewModel.swift` | remove ProgressTracker user script (T7) |
| `ChapterlyCore/Sources/ChapterlyCore/{ReaderProgressPolicy.swift, Assets/ProgressTracker.js}` | **delete** (T7) |
| `ChapterlyCore/Sources/ChapterlyCore/{Payloads,PayloadValidator,ScriptMessageRouter,JSAssets}.swift` | remove progress payload path (T7) |
| `ChapterlyCore/Tests/ChapterlyCoreTests/{PayloadValidatorTests,ScriptMessageRouterTests}.swift` | remove/replace progress tests (T7) |
| `App/SmokeAutopilot.swift` | progress steps → bookmark steps (T7) |
| `App/Features/Settings/SettingsView.swift` | copy: "reading progress" → "bookmarks" (T7) |
| `scripts/smoke-auto.sh` | `EXPECTED_STEPS=8` (T7) |
| `README.md`, `CLAUDE.md` | **proposal only — user must confirm before editing** (T9) |

---

### Task 1: Bookmark field on chapters + store toggle (ChapterlyCore)

**Files:**
- Modify: `ChapterlyCore/Sources/ChapterlyCore/Models.swift`
- Modify: `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Append inside `final class LibraryStoreTests` in `ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift`:

```swift
    func testToggleBookmarkPersistsAndTogglesBack() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let chapter = store.orderedChapters(of: try store.collections()[0])[0]
        XCTAssertFalse(chapter.isBookmarked)

        store.toggleBookmark(chapter)
        // Re-fetch through the store to prove the change was saved, not just mutated in memory.
        XCTAssertEqual(store.chapter(withPageURL: chapter.urlString)?.isBookmarked, true)

        store.toggleBookmark(chapter)
        XCTAssertEqual(store.chapter(withPageURL: chapter.urlString)?.isBookmarked, false)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChapterlyCore && swift test --filter LibraryStoreTests/testToggleBookmarkPersistsAndTogglesBack`
Expected: compile FAILURE — `value of type 'LocalChapterModel' has no member 'isBookmarked'`.

- [ ] **Step 3: Add the model field**

In `ChapterlyCore/Sources/ChapterlyCore/Models.swift`, inside `LocalChapterModel`, after the `excerpt` property (line ~45), add:

```swift
    public var isBookmarked: Bool = false
```

(Default value keeps SwiftData migration lightweight; the `init` does not need a new parameter.)

- [ ] **Step 4: Add the store method**

In `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift`, in the `// MARK: edits` section (after `setProgress`), add:

```swift
    public func toggleBookmark(_ chapter: LocalChapterModel) {
        chapter.isBookmarked.toggle()
        try? context.save()
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ChapterlyCore && swift test --filter LibraryStoreTests`
Expected: all LibraryStoreTests PASS.

- [ ] **Step 6: Run the full core suite**

Run: `cd ChapterlyCore && swift test`
Expected: PASS (no other test touches `LocalChapterModel`'s init shape).

- [ ] **Step 7: Commit**

```bash
git add ChapterlyCore/Sources/ChapterlyCore/Models.swift ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift
git commit -m "feat(core): chapter bookmark flag with store toggle"
```

---

### Task 2: Line-height CSS variable + script (ChapterlyCore)

**Files:**
- Modify: `ChapterlyCore/Sources/ChapterlyCore/Assets/ReaderRuleset.css:27`
- Modify: `ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/ReaderStylerTests.swift`

- [ ] **Step 1: Write the failing tests**

Append inside `final class ReaderStylerTests` in `ChapterlyCore/Tests/ChapterlyCoreTests/ReaderStylerTests.swift`:

```swift
    func testLineHeightScriptSetsVariable() {
        let js = ReaderStyler.lineHeightScript(value: 1.9)
        XCTAssertTrue(js.contains("--chapterly-line-height"))
        XCTAssertTrue(js.contains("1.90"))
    }

    func testLineHeightScriptClampsRange() {
        XCTAssertTrue(ReaderStyler.lineHeightScript(value: 9.0).contains("2.40"))
        XCTAssertTrue(ReaderStyler.lineHeightScript(value: 0.1).contains("1.20"))
    }

    func testRulesetUsesLineHeightVariable() {
        XCTAssertTrue(ReaderStyler.ruleset().contains("var(--chapterly-line-height"))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ChapterlyCore && swift test --filter ReaderStylerTests`
Expected: compile FAILURE — `type 'ReaderStyler' has no member 'lineHeightScript'`.

- [ ] **Step 3: Implement script + CSS**

In `ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift`, directly after `fontSizeScript` (line ~45), add:

```swift
    public static func lineHeightScript(value: Double) -> String {
        let clamped = min(2.4, max(1.2, value))
        let formatted = String(format: "%.2f", clamped)
        return "document.documentElement.style.setProperty('--chapterly-line-height', '\(formatted)');"
    }
```

In `ChapterlyCore/Sources/ChapterlyCore/Assets/ReaderRuleset.css`, change line 27 from:

```css
  line-height: 1.75 !important;
```

to:

```css
  line-height: var(--chapterly-line-height, 1.75) !important;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ChapterlyCore && swift test --filter ReaderStylerTests`
Expected: PASS (including the pre-existing escaping test — CSS still has no backticks or `${`).

- [ ] **Step 5: Commit**

```bash
git add ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift ChapterlyCore/Sources/ChapterlyCore/Assets/ReaderRuleset.css ChapterlyCore/Tests/ChapterlyCoreTests/ReaderStylerTests.swift
git commit -m "feat(core): adjustable reader line-height via CSS variable"
```

---

### Task 3: Library TOC — bookmark icon replaces progress %

**Files:**
- Modify: `App/Features/Library/CollectionTOCView.swift:109-120` (the progress block inside `chapterRow`)

No unit test possible (App target has no test target); verified by build + manual check.

- [ ] **Step 1: Replace the progress display with a bookmark toggle**

In `App/Features/Library/CollectionTOCView.swift`, inside `chapterRow(_:)`, replace this block:

```swift
                if let progress = chapter.readingProgress {
                    if progress >= 0.97 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Finished")
                    } else {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(Int(progress * 100)) percent read")
                    }
                }
```

with:

```swift
                Button {
                    env.store.toggleBookmark(chapter)
                } label: {
                    Image(systemName: chapter.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(chapter.isBookmarked ? Color.accentColor : Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(chapter.isBookmarked ? "Remove bookmark" : "Bookmark this chapter")
                .accessibilityIdentifier("smoke.chapterBookmarkButton")
```

Notes for the engineer:
- `.buttonStyle(.borderless)` is required: inside a `List` row that also has an `.onTapGesture`, a plain `Button` would otherwise let the row tap win. Borderless buttons take tap priority over the parent gesture, so tapping the bookmark must NOT open the reader.
- The 44×44 frame is the minimum accessible hit target.
- `LocalChapterModel` is `@Observable` via `@Model`, so the icon updates immediately when toggled here or from the reader (same model instance, same `ModelContext`).

- [ ] **Step 2: Build the app**

Run: `./scripts/verify.sh`
Expected: build PASS, core tests PASS. (`readingProgress` is still referenced by ReaderView/SmokeAutopilot — they are untouched so far, so nothing breaks.)

- [ ] **Step 3: Manual check (simulator, optional but recommended)**

Open Xcode → Cmd+R → Library → any collection: each row shows an outline `bookmark` icon at the trailing edge of the title line (where the % used to be). Tapping it fills it with the accent color; tapping again returns it to the outline. Tapping the row itself still opens the reader.

- [ ] **Step 4: Commit**

```bash
git add App/Features/Library/CollectionTOCView.swift
git commit -m "feat(library): bookmark toggle replaces reading-progress display in chapter rows"
```

---

### Task 4: PatreonWebView — content-tap and back-swipe-override hooks

**Files:**
- Modify: `App/WebView/PatreonWebView.swift` (full file replacement below)

This is purely additive (new optional parameters defaulting to `nil`), so `BrowseView`'s existing `PatreonWebView(model: env.browse)` call keeps compiling and behaving exactly as before.

- [ ] **Step 1: Replace the file contents**

Replace the entire contents of `App/WebView/PatreonWebView.swift` with:

```swift
import SwiftUI
import WebKit

struct PatreonWebView: UIViewRepresentable {
    let model: WebViewModel
    /// Called when the user taps the page. The Bool is true when the tap landed
    /// in the central region (middle 50% horizontally, middle 40% vertically),
    /// which the reader uses to toggle its chrome without firing on link taps
    /// near the edges.
    var onContentTap: ((Bool) -> Void)? = nil
    /// When set, the left-edge swipe calls this instead of the default
    /// goBack() behavior. The reader uses it to leave the reader.
    var backSwipeOverride: (() -> Void)? = nil

    private static let backSwipeName = "chapterly.backSwipe"
    private static let contentTapName = "chapterly.contentTap"

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView
        context.coordinator.onContentTap = onContentTap
        context.coordinator.backSwipeOverride = backSwipeOverride
        // The web view is shared and outlives this representable; re-attach the
        // gestures to the current coordinator so closures never go stale.
        for gesture in webView.gestureRecognizers ?? []
        where gesture.name == Self.backSwipeName || gesture.name == Self.contentTapName {
            webView.removeGestureRecognizer(gesture)
        }
        let edge = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleBackSwipe(_:)))
        edge.edges = .left
        edge.name = Self.backSwipeName
        webView.addGestureRecognizer(edge)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleContentTap(_:)))
        tap.name = Self.contentTapName
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        webView.addGestureRecognizer(tap)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onContentTap = onContentTap
        context.coordinator.backSwipeOverride = backSwipeOverride
    }

    /// Patreon navigates client-side (same-document history entries), which
    /// WKWebView's built-in back gesture ignores even though goBack() handles
    /// them fine — so drive goBack() from our own left-edge swipe.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onContentTap: ((Bool) -> Void)?
        var backSwipeOverride: (() -> Void)?

        @objc func handleBackSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended,
                  let webView = gesture.view as? WKWebView,
                  gesture.translation(in: webView).x > 60 else { return }
            if let backSwipeOverride {
                backSwipeOverride()
            } else if webView.canGoBack {
                webView.goBack()
            }
        }

        @objc func handleContentTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let view = gesture.view,
                  let onContentTap else { return }
            let point = gesture.location(in: view)
            let bounds = view.bounds
            let isCenter = point.x > bounds.width * 0.25 && point.x < bounds.width * 0.75
                && point.y > bounds.height * 0.30 && point.y < bounds.height * 0.70
            onContentTap(isCenter)
        }

        // The web view must keep receiving the same touches (links, scrolling).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `./scripts/verify.sh`
Expected: PASS. Browse tab behavior unchanged (no `onContentTap`, no `backSwipeOverride` → tap does nothing extra, swipe still calls `goBack()` when possible).

- [ ] **Step 3: Commit**

```bash
git add App/WebView/PatreonWebView.swift
git commit -m "feat(webview): optional content-tap and back-swipe-override hooks for the reader"
```

---

### Task 5: Reader overhaul — hidden chrome, bookmark, swipe-to-leave, preferences panel

**Files:**
- Modify: `App/Features/Reader/ReaderPreferences.swift` (full replacement)
- Create: `App/Features/Reader/ReaderPreferencesPanel.swift`
- Modify: `App/Features/Reader/ReaderView.swift` (full replacement)

All three change in one commit because they reference each other (`readerModeEnabled` disappears, `lineSpacing` appears).

Design decisions locked in (do not re-derive):
- Chrome (top bar, foreign-page banner, prefs panel, bottom prev/next bar) is **hidden on open**. A tap in the page center toggles it; top chrome slides down from the top edge, bottom bar slides up from the bottom (`.transition(.move(edge:))` + `withAnimation(.easeInOut(duration: 0.25))`) — exactly the requested "上方的UI往下展開，下方的則往上".
- The old `chevron.down` dismiss button is gone. Leaving the reader = left-edge swipe. On a foreign page with web history the swipe first goes back toward the chapter; otherwise it dismisses the reader.
- Reader mode is **always on** for library chapters — the toggle and the "Open on Patreon" link are removed entirely. Foreign pages still get the CSS stripped (unchanged behavior).
- Chapters always open at the **top**: `enforceScrollScript(progress: nil)`. No progress is restored anymore (the plumbing is deleted in Task 7; this task just stops using it).
- The preferences panel is **full-width**, sits under the top bar, never closes when its buttons are tapped (readers tap repeatedly), and closes when the user taps anywhere on the page outside it or hides the chrome.
- Panel layout matches the provided mock: 2×2 grid of gray capsule buttons — row 1: small "A" (decrease font) | large "A" (increase font); row 2: `arrow.down.and.line.horizontal.and.arrow.up` (decrease line spacing) | `arrow.up.and.line.horizontal.and.arrow.down` (increase line spacing).
- Buttons disable (40% opacity) at the clamp limits: font 14–32 pt, line spacing 1.2–2.4 in 0.1 steps, default 1.75.

- [ ] **Step 1: Replace `ReaderPreferences.swift`**

Replace the entire contents of `App/Features/Reader/ReaderPreferences.swift` with:

```swift
import SwiftUI

@MainActor
@Observable
final class ReaderPreferences {
    static let fontSizeRange = 14...32
    static let lineSpacingRange = 1.2...2.4
    static let lineSpacingStep = 0.1

    var fontSize: Int {
        didSet {
            fontSize = min(Self.fontSizeRange.upperBound,
                           max(Self.fontSizeRange.lowerBound, fontSize))
            UserDefaults.standard.set(fontSize, forKey: "reader.fontSize")
        }
    }

    /// CSS line-height multiplier applied to the reading column.
    var lineSpacing: Double {
        didSet {
            lineSpacing = min(Self.lineSpacingRange.upperBound,
                              max(Self.lineSpacingRange.lowerBound, lineSpacing))
            UserDefaults.standard.set(lineSpacing, forKey: "reader.lineSpacing")
        }
    }

    init() {
        let storedSize = UserDefaults.standard.integer(forKey: "reader.fontSize")
        fontSize = storedSize == 0 ? 19 : storedSize
        let storedSpacing = UserDefaults.standard.double(forKey: "reader.lineSpacing")
        lineSpacing = storedSpacing == 0 ? 1.75 : storedSpacing
    }
}
```

(Reassigning a property inside its own `didSet` does not re-trigger the observer — this is the documented Swift clamping idiom. The orphaned `"reader.enabled"` UserDefaults key from the removed toggle is harmless and is intentionally left behind.)

- [ ] **Step 2: Create `ReaderPreferencesPanel.swift`**

Create `App/Features/Reader/ReaderPreferencesPanel.swift` with:

```swift
import SwiftUI

/// Full-width reading-preferences panel shown under the reader's top bar.
/// Buttons never dismiss the panel — readers tap them repeatedly until the
/// text looks right. Tapping the page outside the panel closes it.
struct ReaderPreferencesPanel: View {
    let prefs: ReaderPreferences

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                controlButton(disabled: prefs.fontSize <= ReaderPreferences.fontSizeRange.lowerBound,
                              accessibilityLabel: "Decrease font size",
                              action: { prefs.fontSize -= 1 }) {
                    Text("A").font(.system(size: 15))
                }
                controlButton(disabled: prefs.fontSize >= ReaderPreferences.fontSizeRange.upperBound,
                              accessibilityLabel: "Increase font size",
                              action: { prefs.fontSize += 1 }) {
                    Text("A").font(.system(size: 26))
                }
            }
            GridRow {
                controlButton(disabled: prefs.lineSpacing <= ReaderPreferences.lineSpacingRange.lowerBound + 0.001,
                              accessibilityLabel: "Decrease line spacing",
                              action: { prefs.lineSpacing -= ReaderPreferences.lineSpacingStep }) {
                    Image(systemName: "arrow.down.and.line.horizontal.and.arrow.up")
                }
                controlButton(disabled: prefs.lineSpacing >= ReaderPreferences.lineSpacingRange.upperBound - 0.001,
                              accessibilityLabel: "Increase line spacing",
                              action: { prefs.lineSpacing += ReaderPreferences.lineSpacingStep }) {
                    Image(systemName: "arrow.up.and.line.horizontal.and.arrow.down")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .accessibilityIdentifier("smoke.readerPrefsPanel")
    }

    private func controlButton(disabled: Bool,
                               accessibilityLabel: String,
                               action: @escaping () -> Void,
                               @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.secondarySystemFill), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}
```

- [ ] **Step 3: Replace `ReaderView.swift`**

Replace the entire contents of `App/Features/Reader/ReaderView.swift` with:

```swift
import SwiftUI
import WebKit
import ChapterlyCore

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var current: LocalChapterModel
    @State private var prefs = ReaderPreferences()
    /// Reader chrome (top/bottom bars) is hidden by default; tapping the
    /// center of the page toggles it.
    @State private var chromeVisible = false
    @State private var showPrefsPanel = false
    /// Non-nil while the web view shows a page outside the library (e.g. a related
    /// post from a collection that has not been imported). Holds the display title.
    @State private var foreignPageTitle: String?
    @State private var foreignTitleTask: Task<Void, Never>?
    /// Identity of the foreign page currently shown (post ID when available),
    /// so SPA URL rewrites on the same page don't re-pin the scroll position.
    @State private var foreignPageKey: String?

    init(chapter: LocalChapterModel) {
        _current = State(initialValue: chapter)
    }

    var body: some View {
        PatreonWebView(model: env.reader,
                       onContentTap: handleContentTap(isCenter:),
                       backSwipeOverride: handleBackSwipe)
            .accessibilityIdentifier("smoke.readerWebView")
            .overlay(alignment: .top) { topChrome }
            .overlay(alignment: .bottom) { bottomChrome }
            .onAppear { open(current) }
            .onDisappear { foreignTitleTask?.cancel() }
            .onChange(of: env.reader.finishedNavigationCount) { _, _ in applyReaderTreatment() }
            .onChange(of: env.reader.currentURL) { _, newURL in syncCurrentChapter(to: newURL) }
            .onChange(of: prefs.fontSize) { _, size in
                env.reader.webView.evaluateJavaScript(
                    ReaderStyler.fontSizeScript(points: size), completionHandler: nil)
            }
            .onChange(of: prefs.lineSpacing) { _, spacing in
                env.reader.webView.evaluateJavaScript(
                    ReaderStyler.lineHeightScript(value: spacing), completionHandler: nil)
            }
    }

    // MARK: - Chrome

    @ViewBuilder private var topChrome: some View {
        if chromeVisible {
            VStack(spacing: 0) {
                topBar
                if foreignPageTitle != nil {
                    WebCollectionBanner(model: env.reader)
                }
                if showPrefsPanel {
                    ReaderPreferencesPanel(prefs: prefs)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder private var bottomChrome: some View {
        if chromeVisible {
            bottomBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func handleContentTap(isCenter: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if showPrefsPanel {
                // Any tap on the page outside the panel closes just the panel.
                showPrefsPanel = false
            } else if isCenter {
                chromeVisible.toggle()
            }
        }
    }

    /// Left-edge swipe: a foreign page first goes back toward the chapter it
    /// was opened from; on a library chapter the swipe leaves the reader.
    private func handleBackSwipe() {
        if foreignPageTitle != nil && env.reader.webView.canGoBack {
            env.reader.webView.goBack()
        } else {
            dismiss()
        }
    }

    // MARK: - Navigation / state sync

    private var neighbors: (previous: LocalChapterModel?, next: LocalChapterModel?) {
        foreignPageTitle == nil ? env.store.neighbors(of: current) : (nil, nil)
    }

    private var currentTitle: String {
        if let foreignPageTitle { return foreignPageTitle }
        return ChapterTextFormatter.presentation(storedTitle: current.title,
                                                 urlString: current.urlString).title
    }

    private func open(_ chapter: LocalChapterModel) {
        foreignTitleTask?.cancel()
        foreignPageTitle = nil
        foreignPageKey = nil
        current = chapter
        if let url = URL(string: chapter.urlString) {
            env.reader.load(url)
        }
    }

    /// Patreon navigates between posts client-side (SPA), so didFinish may never fire.
    /// Keep `current` in sync with whatever article the web view actually shows.
    /// Pages outside the library (e.g. not-yet-imported related posts) get a
    /// "foreign" state: the title comes from the page itself and prev/next
    /// navigation is hidden.
    private func syncCurrentChapter(to url: URL?) {
        guard let url else { return }
        if let chapter = env.store.chapter(withPageURL: url.absoluteString) {
            foreignTitleTask?.cancel()
            let wasForeign = foreignPageTitle != nil
            foreignPageTitle = nil
            foreignPageKey = nil
            if chapter.id != current.id {
                current = chapter
                applyReaderTreatment()
            } else if wasForeign {
                // SPA return to the chapter we were already on: didFinish never fires,
                // so re-apply treatment here or the page keeps Patreon's auto-scroll.
                applyReaderTreatment()
            }
        } else {
            let key = URLNormalizer.patreonPostID(url.absoluteString)
                ?? URLNormalizer.normalize(url.absoluteString)?.absoluteString
                ?? url.absoluteString
            let samePage = foreignPageTitle != nil && key == foreignPageKey
            foreignPageKey = key
            guard !samePage else { return }
            let staleTitles: Set<String> = [current.title, currentTitle]
            let slugTitle = ChapterTextFormatter.presentation(storedTitle: "",
                                                              urlString: url.absoluteString).title
            foreignPageTitle = slugTitle.isEmpty ? "Patreon post" : slugTitle
            applyReaderTreatment()
            pollForeignTitle(rejecting: staleTitles)
        }
    }

    /// The SPA may still render the previous post for a moment after the URL changes,
    /// so poll briefly and keep the latest title the page settles on. Titles matching
    /// the chapter we navigated away from are ignored.
    private func pollForeignTitle(rejecting staleTitles: Set<String>) {
        foreignTitleTask?.cancel()
        foreignTitleTask = Task { @MainActor in
            for _ in 0..<8 {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, foreignPageTitle != nil else { return }
                // The one-shot collection detect can race the SPA render; refresh it
                // alongside the title so the series banner reflects the settled page.
                env.reader.runCollectionDetect()
                env.reader.webView.evaluateJavaScript(Self.readerTitleScript) { result, _ in
                    Task { @MainActor in
                        guard foreignPageTitle != nil,
                              let title = result as? String, !title.isEmpty,
                              !staleTitles.contains(title) else { return }
                        foreignPageTitle = title
                    }
                }
            }
        }
    }

    // MARK: - Page treatment

    private func applyReaderTreatment() {
        guard env.reader.currentURL != nil else { return }
        let webView = env.reader.webView
        if foreignPageTitle == nil {
            webView.evaluateJavaScript(ReaderStyler.injectionScript(), completionHandler: nil)
            webView.evaluateJavaScript(ReaderStyler.fontSizeScript(points: prefs.fontSize),
                                       completionHandler: nil)
            webView.evaluateJavaScript(ReaderStyler.lineHeightScript(value: prefs.lineSpacing),
                                       completionHandler: nil)
            repairCurrentTitleIfNeeded(webView)
        } else {
            // The ruleset is post-page specific: on creator/collection pages it
            // hides the chrome and squeezes the feed, so strip it there.
            webView.evaluateJavaScript(ReaderStyler.removalScript(), completionHandler: nil)
        }
        // Every page opens at the top; the enforcer also defeats Patreon's own
        // auto-scroll on freshly loaded pages.
        webView.evaluateJavaScript(ReaderStyler.enforceScrollScript(progress: nil),
                                   completionHandler: nil)
    }

    private func repairCurrentTitleIfNeeded(_ webView: WKWebView) {
        guard ChapterTextFormatter.isProbablyContaminatedTitle(current.title) else { return }
        webView.evaluateJavaScript(Self.readerTitleScript) { result, _ in
            guard let title = result as? String, !title.isEmpty,
                  !ChapterTextFormatter.isProbablyContaminatedTitle(title)
            else { return }
            Task { @MainActor in
                env.store.rename(current, to: title)
            }
        }
    }

    private static let readerTitleScript = """
    (function () {
      function compact(value) {
        return (value || "").replace(/\\s+/g, " ").trim();
      }
      function candidate(value) {
        var text = compact(value);
        return text && text.length <= 180 ? text : "";
      }
      var selectors = ['[data-tag="post-title"]', '[data-testid="post-title"]', 'article h1', 'h1'];
      for (var i = 0; i < selectors.length; i++) {
        var node = document.querySelector(selectors[i]);
        var title = candidate(node && node.textContent);
        if (title) { return title; }
      }
      return candidate((document.title || "").replace(/\\s*\\|\\s*Patreon.*$/i, ""));
    })();
    """

    // MARK: - Bars

    private var topBar: some View {
        HStack {
            if foreignPageTitle == nil {
                Button {
                    env.store.toggleBookmark(current)
                } label: {
                    Image(systemName: current.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(current.isBookmarked ? Color.accentColor : Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(current.isBookmarked ? "Remove bookmark" : "Bookmark this chapter")
                .accessibilityIdentifier("smoke.readerBookmarkButton")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            Text(currentTitle).font(.subheadline.weight(.medium)).lineLimit(1)
                .accessibilityIdentifier("smoke.readerTitle")
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showPrefsPanel.toggle() }
            } label: {
                Image(systemName: "textformat.size")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reading options")
            .accessibilityIdentifier("smoke.readerPrefsButton")
        }
        .padding(.horizontal, 4)
        .background(.bar)
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if let previous = neighbors.previous {
                Button { open(previous) } label: {
                    Label("上一章", systemImage: "chevron.left")
                }
            } else {
                // Color is greedy in both axes; without a height the bar grows to fill the screen.
                Color.clear.frame(width: 72, height: 0)
            }
            Text(currentTitle)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            if let next = neighbors.next {
                Button { open(next) } label: {
                    HStack {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                }
            } else {
                Color.clear.frame(width: 72, height: 0)
            }
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
```

What changed vs. the old file (for review orientation): `targetProgress` is gone (always open at top), `prefs.readerModeEnabled` checks are gone (always on for library pages), the `Menu` is replaced by the panel toggle, the dismiss chevron is replaced by the bookmark button, bars moved from a `VStack` into overlays so toggling them never reflows the web view, and the two `onChange(of: prefs.…)` modifiers moved to the body.

- [ ] **Step 4: Build**

Run: `./scripts/verify.sh`
Expected: build PASS, core tests PASS. (SmokeAutopilot still compiles — `readingProgress` still exists on the model until Task 7.)

- [ ] **Step 5: Manual check (simulator)**

Cmd+R, Library → collection → tap a chapter:
1. Reader opens with NO bars; article starts at the top.
2. Tap page center → top bar slides down, bottom bar slides up. Tap center again → both hide.
3. Top bar: bookmark icon left (toggles fill, and the same chapter's icon in the TOC matches after swiping back), title center, `textformat.size` right.
4. Tap `textformat.size` → full-width panel under the bar. Tap "A" buttons repeatedly → text grows/shrinks live, panel stays open. Tap line-spacing buttons repeatedly → spacing changes live, panel stays open. Tap article area → panel closes, bars stay.
5. Left-edge swipe → returns to the TOC.
6. Tap a related-post link inside an article (foreign page) → CSS stripped; tap center → banner shows under top bar; left-edge swipe → back to the chapter; swipe again → leaves the reader.

- [ ] **Step 6: Commit**

```bash
git add App/Features/Reader/ReaderPreferences.swift App/Features/Reader/ReaderPreferencesPanel.swift App/Features/Reader/ReaderView.swift
git commit -m "feat(reader): immersive chrome, bookmark toggle, swipe-to-leave, full-width preferences panel"
```

---

### Task 6: "Check for new chapters" replaces manual add

**Files:**
- Modify: `App/AppEnvironment.swift` (add `refresher`, `refreshCollection`, outcome enum)
- Modify: `App/Features/Library/CollectionTOCView.swift` (toolbar + remove add-sheet)
- Modify: `App/Features/Shared/WebCollectionBanner.swift:24` (stale copy)
- Modify: `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift` (remove `addManualChapter`)
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift` (remove manual-add test)

How it works: the collection's `sourceURLString` is loaded in a third, offscreen `WebViewModel` that shares the default website data store (so the user's manual Patreon login applies). Once the page finishes loading, the existing `CollectionImport.js` runs — it already scrolls/clicks "load more" until the list stops growing and posts every chapter to the import handler, and `applyImport` already merges without duplicating. New-chapter count = the collection's chapter count delta.

- [ ] **Step 1: Add the refresher and refresh flow to `AppEnvironment.swift`**

In `App/AppEnvironment.swift`:

1. Above `final class AppEnvironment` (file scope), add:

```swift
enum CollectionRefreshOutcome: Equatable {
    case newChapters(Int)
    case upToDate
    case needsLogin
    case failed
}
```

2. Change the model properties (line ~13-14) from:

```swift
    let browse = WebViewModel()
    let reader = WebViewModel()
```

to:

```swift
    let browse = WebViewModel()
    let reader = WebViewModel()
    /// Offscreen web view used to re-crawl a collection page for new chapters.
    let refresher = WebViewModel()
```

3. In `init()`, after `wire(reader)`, add:

```swift
        wire(refresher)
```

4. After the `wire(_:)` method, add:

```swift
    /// Loads the collection's source page in the offscreen refresher web view and
    /// re-runs the chapter import. `applyImport` merges by normalized URL, so
    /// already-imported chapters are untouched and only genuinely new posts land.
    func refreshCollection(_ collection: LocalCollectionModel) async -> CollectionRefreshOutcome {
        guard let url = URL(string: collection.sourceURLString) else { return .failed }
        // An offscreen WKWebView needs a real frame for layout-driven lazy lists.
        if refresher.webView.frame.isEmpty {
            refresher.webView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        }
        let countBefore = collection.chapters.count
        let baseline = refresher.finishedNavigationCount
        refresher.load(url)
        let loaded = await waitUntil(timeout: .seconds(30)) { [refresher] in
            refresher.finishedNavigationCount > baseline && !refresher.webView.isLoading
        }
        guard loaded else { return .failed }
        if refresher.currentURL?.path.contains("/login") == true { return .needsLogin }
        await refresher.runCollectionImport()
        // applyImport flushes 300 ms after the last chapter message lands;
        // wait it out before counting.
        try? await Task.sleep(for: .milliseconds(600))
        let delta = collection.chapters.count - countBefore
        return delta > 0 ? .newChapters(delta) : .upToDate
    }

    private func waitUntil(timeout: Duration,
                           _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }
```

(Known, accepted limitation: `importedCountThisSession` is shared with the Browse-tab import banner; running both imports at the same instant would mix the counts. The refresh outcome itself uses the chapter-count delta, so its message is always correct.)

- [ ] **Step 2: Swap the TOC toolbar button and delete the add-sheet**

In `App/Features/Library/CollectionTOCView.swift`:

1. Replace the state properties:

```swift
    @State private var showAddSheet = false
    @State private var newTitle = ""
    @State private var newURL = ""
```

with:

```swift
    @State private var refreshing = false
    @State private var refreshOutcome: CollectionRefreshOutcome?
    @State private var showRefreshResult = false
```

2. In the `.toolbar` block, replace:

```swift
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add chapter manually")
```

with:

```swift
                Button {
                    refreshing = true
                    Task {
                        refreshOutcome = await env.refreshCollection(collection)
                        refreshing = false
                        showRefreshResult = true
                    }
                } label: {
                    if refreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(refreshing)
                .accessibilityLabel("Check for new chapters")
                .accessibilityIdentifier("smoke.refreshChaptersButton")
```

3. Delete the entire `.sheet(isPresented: $showAddSheet) { … }` modifier (the `NavigationStack`/`Form` with Title/URL fields, lines ~68-91 in the current file).

4. In its place add the result alert:

```swift
        .alert(refreshAlertTitle, isPresented: $showRefreshResult) {
            Button("OK") {}
        } message: {
            Text(refreshAlertMessage)
        }
```

5. Add the two computed properties (below `chapters`):

```swift
    private var refreshAlertTitle: String {
        switch refreshOutcome {
        case .newChapters: return "New chapters imported"
        case .upToDate: return "Up to date"
        case .needsLogin: return "Login required"
        case .failed, nil: return "Could not check"
        }
    }

    private var refreshAlertMessage: String {
        switch refreshOutcome {
        case .newChapters(let count):
            return "Imported \(count) new chapter\(count == 1 ? "" : "s")."
        case .upToDate:
            return "Your library already matches this collection."
        case .needsLogin:
            return "Patreon asked for login. Open the Browse tab, log in, then try again."
        case .failed, nil:
            return "Could not load the collection page. Check your connection and try again."
        }
    }
```

- [ ] **Step 3: Remove the now-dead store API and its test**

In `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift`, delete the whole `addManualChapter(to:title:urlString:)` method.

In `ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift`, replace `testManualAddRenameDelete` with a version that keeps the rename/delete coverage:

```swift
    func testRenameAndDelete() throws {
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let collection = try store.collections()[0]
        let chapters = store.orderedChapters(of: collection)
        store.rename(chapters[1], to: "5 脣瓣 (fixed)")
        store.delete(chapters[0])
        let remaining = store.orderedChapters(of: collection)
        XCTAssertEqual(remaining.map(\.title), ["5 脣瓣 (fixed)"])
    }
```

- [ ] **Step 4: Update the stale "add manually" copy in the import banner**

In `App/Features/Shared/WebCollectionBanner.swift`, replace:

```swift
                    Text("No chapter links were found on this page. Patreon's markup may have changed — you can add chapters manually from the collection's page in Library.")
```

with:

```swift
                    Text("No chapter links were found on this page. Make sure the collection page finished loading, then try again. Patreon's markup may also have changed.")
```

- [ ] **Step 5: Build + tests**

Run: `./scripts/verify.sh`
Expected: PASS (manual-add references are gone from both targets).

- [ ] **Step 6: Manual check (simulator, needs Patreon login)**

Library → a previously imported collection → tap the circular-arrows toolbar button:
- Spinner shows in the toolbar while it works (long serials can take a couple of minutes — the import script keeps clicking "load more").
- If Patreon released new posts since the import: alert "Imported N new chapters." and the rows appear in order.
- Otherwise: "Up to date".
- Logged out: "Login required" message.

- [ ] **Step 7: Commit**

```bash
git add App/AppEnvironment.swift App/Features/Library/CollectionTOCView.swift App/Features/Shared/WebCollectionBanner.swift ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift
git commit -m "feat(library): one-tap check-for-new-chapters replaces manual chapter entry"
```

---

### Task 7: Remove the reading-progress feature end-to-end + repurpose smoke steps

Everything that stored/restored scroll progress goes away; the smoke autopilot's two progress steps become bookmark steps so `smoke-auto.sh` still proves persistence across relaunch. This is one commit because the core deletions and the app/autopilot references must change together to keep the build green.

**Files:**
- Delete: `ChapterlyCore/Sources/ChapterlyCore/ReaderProgressPolicy.swift`
- Delete: `ChapterlyCore/Sources/ChapterlyCore/Assets/ProgressTracker.js`
- Modify: `ChapterlyCore/Sources/ChapterlyCore/Payloads.swift`, `PayloadValidator.swift`, `ScriptMessageRouter.swift`, `JSAssets.swift`, `LibraryStore.swift`, `Models.swift`, `ReaderStyler.swift`
- Modify tests: `LibraryStoreTests.swift`, `PayloadValidatorTests.swift`, `ScriptMessageRouterTests.swift`, `ReaderStylerTests.swift`
- Modify: `App/WebView/WebViewModel.swift`, `App/AppEnvironment.swift`, `App/SmokeAutopilot.swift`, `App/Features/Settings/SettingsView.swift`
- Modify: `scripts/smoke-auto.sh`

- [ ] **Step 1: Core — delete the progress message path**

1. Delete files:

```bash
git rm ChapterlyCore/Sources/ChapterlyCore/ReaderProgressPolicy.swift ChapterlyCore/Sources/ChapterlyCore/Assets/ProgressTracker.js
```

2. `Payloads.swift`: delete the whole `ProgressPayload` struct (lines ~38-46).

3. `PayloadValidator.swift`: delete the whole `validateProgress(_:)` method (lines ~40-49).

4. `ScriptMessageRouter.swift`: delete `progressName`, `onProgress`, and the progress case so the type reads:

```swift
public final class ScriptMessageRouter {
    public static let importName = "chapterlyImport"
    public static let collectionLinkName = "chapterlyCollectionLink"

    public static var allHandlerNames: [String] { [importName, collectionLinkName] }

    public var onImporterChapter: ((ImporterChapterPayload) -> Void)?
    public var onCollectionLink: ((CollectionLinkPayload) -> Void)?
```

and in `route(name:body:)` delete the `case Self.progressName:` branch.

5. `JSAssets.swift`: delete the line `public static var progressTracker: String { script(named: "ProgressTracker") }`.

6. `LibraryStore.swift`: delete the whole `setProgress(forPageURL:progress:)` method.

7. `Models.swift`: in `LocalChapterModel`, delete:

```swift
    public var readingProgress: Double?
    public var lastReadAt: Date?
```

8. `ReaderStyler.swift`: delete the whole `restoreScrollScript(progress:)` and `scrollToTopScript()` methods, and replace `enforceScrollScript`'s doc comment with:

```swift
    /// Pins the scroll position to `progress` (or top when nil) for a few seconds,
    /// re-applying every 400ms to defeat Patreon's own auto-scroll. Stops as soon
    /// as the user touches or wheel-scrolls the page.
```

- [ ] **Step 2: Core — update the tests**

1. `LibraryStoreTests.swift`: delete `testProgressSavedByNormalizedURL`, `testProgressSavedByMatchingPatreonPostIDWhenSlugChanges`, and `testFooterScrollDoesNotOverwriteReadingProgress`. The post-ID URL matching they partially covered stays covered: add this replacement test so `chapter(withPageURL:)`'s slug-change fallback keeps a test:

```swift
    func testChapterLookupMatchesByPatreonPostIDWhenSlugChanges() throws {
        try store.applyImport([payload("Chapter", "https://patreon.com/posts/160628832", order: 0)])
        let chapter = store.chapter(
            withPageURL: "https://www.patreon.com/posts/chapter-title-160628832?utm_source=share")
        XCTAssertEqual(chapter?.title, "Chapter")
    }
```

2. `PayloadValidatorTests.swift`: delete `testValidProgressPayload`, `testProgressClampedToUnitRange`, `testProgressRejectsForbiddenExtraField`, and `testProgressRejectsUnknownExtraField`. (Forbidden/unknown-key rejection stays covered by the importer-payload tests in the same file.)

3. `ScriptMessageRouterTests.swift`: replace `testRoutesProgressAndCollectionLink` with:

```swift
    func testRoutesCollectionLink() {
        var links: [CollectionLinkPayload] = []
        let router = ScriptMessageRouter()
        router.onCollectionLink = { links.append($0) }
        router.route(name: ScriptMessageRouter.collectionLinkName,
                     body: ["collectionName": "焚心",
                            "collectionURL": "https://patreon.com/collection/9"] as [String: Any])
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(router.rejectedCount, 0)
    }
```

4. `ReaderStylerTests.swift`: delete `testScrollToTopScript`.

- [ ] **Step 3: Run core tests**

Run: `cd ChapterlyCore && swift test`
Expected: PASS, zero references to progress remain (`grep -rn "rogress" ChapterlyCore/Sources` returns nothing).

- [ ] **Step 4: App — remove progress wiring**

1. `App/WebView/WebViewModel.swift`: delete the ProgressTracker user-script registration:

```swift
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.progressTracker,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
```

2. `App/AppEnvironment.swift`: in `wire(_:)`, delete the whole `model.router.onProgress = { … }` closure block.

3. `App/Features/Settings/SettingsView.swift`: update the three copy strings —
   - "Clear Library Data deletes collections, chapters, and reading progress stored on this device. …" → "Clear Library Data deletes collections, chapters, and bookmarks stored on this device. Logout from Patreon ends the website session in the built-in browser. The two are independent."
   - "… It stores chapter titles, links, and reading progress on this device — never post content. …" → "… It stores chapter titles, links, and bookmarks on this device — never post content. Patreon controls all access to posts." (keep the surrounding sentence as-is)
   - confirmationDialog title "Delete all collections, chapters, and reading progress?" → "Delete all collections, chapters, and bookmarks?"

- [ ] **Step 5: App — repurpose the smoke autopilot steps**

In `App/SmokeAutopilot.swift`:

1. Update the class doc comment's step list mention (replace "scrolls" wording): `…imports chapters, opens the reader, toggles a bookmark, and logs one [SMOKE] step=… line per step.`

2. Replace the end of `runPhase1()` — everything from the `// ProgressTracker only saves…` comment through `pass("progress_save")` — with:

```swift
        env.store.toggleBookmark(chapter)
        let bookmarked = await waitUntil { [env] in
            env.store.chapter(withPageURL: chapter.urlString)?.isBookmarked == true
        }
        guard bookmarked else {
            fail("bookmark_save", "isBookmarked_still_false")
            return
        }
        pass("bookmark_save")
```

and update the `// MARK:` comment above `runPhase1` to `auth -> collection -> import -> reader -> css -> bookmark save`.

3. Replace the whole `runPhase2()` with:

```swift
    // MARK: - Phase 2: bookmark persists across relaunch + reader opens at top

    private func runPhase2() async {
        guard let chapter = firstBookmarkedChapter() else {
            fail("bookmark_restore", "no_bookmarked_chapter_found")
            return
        }
        pass("bookmark_restore")

        guard await openReader(chapter, stepName: "reader_top") else { return }
        // ReaderView pins the scroll to the top for a few seconds after load;
        // poll until the page actually sits at (or extremely near) the top.
        let atTop = await waitUntil { [env] in
            guard let p = await Self.scrollProgress(of: env.reader.webView) else { return false }
            return p <= 0.05
        }
        guard atTop else {
            let actual = (await Self.scrollProgress(of: env.reader.webView))
                .map { String(format: "%.2f", $0) } ?? "nil"
            fail("reader_top", "scroll=\(actual)_expected<=0.05")
            return
        }
        pass("reader_top")
    }
```

4. Replace `firstChapterWithProgress()` with:

```swift
    private func firstBookmarkedChapter() -> LocalChapterModel? {
        guard let collection = (try? env.store.collections())?.first else { return nil }
        return env.store.orderedChapters(of: collection).first { $0.isBookmarked }
    }
```

(`scrollProgress(of:)`, `waitUntil`, `openReader` all stay.)

- [ ] **Step 6: Update the smoke driver script**

In `scripts/smoke-auto.sh`, change line 18 from `EXPECTED_STEPS=7` to `EXPECTED_STEPS=8` (phase 1: auth, collection_detect, import, open_reader, reader_css, bookmark_save = 6; phase 2: bookmark_restore, reader_top = 2). If the header comment block enumerates the old step names, update those words too.

- [ ] **Step 7: Verify everything**

Run: `./scripts/verify.sh`
Expected: PASS. Then: `grep -rn "readingProgress\|ProgressPayload\|progressTracker\|setProgress\|ReaderProgressPolicy" App ChapterlyCore/Sources ChapterlyCore/Tests scripts | grep -v .build` returns nothing.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat!: remove reading-progress feature; smoke loop now exercises bookmarks

Chapters always open at the top. ProgressTracker.js, the chapterlyProgress
message handler, ReaderProgressPolicy, and the model fields are deleted
(lightweight SwiftData migration drops old values). smoke-auto.sh now expects
8 steps: bookmark_save replaces progress_save, and phase 2 checks
bookmark_restore + reader_top."
```

---

### Task 8: Final verification

- [ ] **Step 1: Clean automated run**

```bash
./scripts/verify.sh
```
Expected: build PASS + all ChapterlyCore tests PASS.

- [ ] **Step 2: Manual smoke (user-assisted — requires the user's Patreon login)**

Ask the user to confirm the simulator is still logged in to Patreon and `.env` has `SMOKE_TEST_URL`, then run:

```bash
./scripts/smoke-auto.sh
```
Expected: `PASS: all 8 steps passed - goal condition met`. On failure, read `build/smoke/auto-report.md`, `build/smoke/auto-phase1.log`, `build/smoke/auto-phase2.log`, `build/smoke/app.log` BEFORE changing code (CLAUDE.md debugging loop). Do not uninstall the app or erase the simulator — that destroys the login.

- [ ] **Step 3: Manual UX sweep (simulator)**

Full checklist in one pass: TOC bookmark toggle ↔ reader bookmark stays in sync; reader opens at top with no chrome; center-tap reveal animation (top slides down, bottom slides up); panel buttons repeat without closing; outside tap closes panel; left-edge swipe leaves reader; refresh button outcomes; Browse tab unaffected (banner import, back swipe, card taps still work).

---

### Task 9: Documentation updates (USER CONFIRMATION GATE — do not edit without approval)

The user's global CLAUDE.md has a README consistency gate: propose first, edit only after confirmation.

- [ ] **Step 1: Present this proposal to the user and STOP until they answer**

Proposed `README.md` changes:
- Line 6: "locally saved reading progress." → describe bookmarks instead (feature removed/replaced).
- Line 58: drop "Reading progress is approximate (lazy-loaded images shift page height)." — no longer applies.
- Mention the new "check for new chapters" button and the tap-center reader chrome if the README describes the old flows.

Proposed project `CLAUDE.md` changes (project instruction file — same confirmation):
- "Progress Save / Restore Debugging" section → replace with a short "Bookmark Debugging" section (storage field `isBookmarked`, deterministic store test, no simulator erase).
- Smoke loop description: step list now ends in `bookmark_save` / `bookmark_restore` + `reader_top`; exit-code semantics unchanged; `EXPECTED_STEPS=8`.
- Identifier list: replace `smoke.progressIndicator` with `smoke.chapterBookmarkButton`, `smoke.readerBookmarkButton`, `smoke.readerPrefsButton`, `smoke.refreshChaptersButton`; `smoke.importChaptersButton` etc. unchanged.
- Example diagnostic output mentioning `readerProgressEntries…` → bookmark-count equivalents.

- [ ] **Step 2: After explicit user confirmation, apply the agreed edits and commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: bookmarks replace reading progress; new-chapter refresh and reader chrome documented"
```

---

## Self-review notes (already applied)

- **Spec coverage:** (1) auto-fetch new chapters → Task 6; (2) no progress retention, open at top → Tasks 5 + 7; (3) bookmark in TOC rows + reader top bar, synced, swipe-to-leave replaces collapse chevron → Tasks 1, 3, 4, 5; (4) reader mode always on, "Open on Patreon" removed, chrome hidden until center tap with split slide animation, line-spacing buttons per mock, full-width non-dismissing panel closed by outside tap → Tasks 2, 5.
- **Type consistency:** `toggleBookmark(_:)`, `isBookmarked`, `lineHeightScript(value:)`, `lineSpacing`, `CollectionRefreshOutcome`, `refreshCollection(_:)`, `firstBookmarkedChapter()` — names match across all tasks.
- **Deliberate scope cuts (YAGNI):** no bookmark filter/sort view, no multi-bookmark per chapter, no automatic background refresh of all collections, no haptics. The `"reader.enabled"` UserDefaults key is orphaned on purpose.
- **Known risks called out:** offscreen WKWebView lazy-list crawling (mitigated by giving it a real frame; if a long serial still under-imports, the same import works from the Browse tab as before), shared `importedCountThisSession` counter (cosmetic only), tap-to-toggle firing on link taps (mitigated by the center-region filter).
