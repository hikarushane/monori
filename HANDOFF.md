# HANDOFF

> 上次 session: 2026-06-18（Google 2FA 登入 redirect 修正）
> 下次接手請從「接手要做的事」開始

## 狀態
Feature branch `feat/google-docs-import`（off `main`）。Google Docs import 全 14 tasks 完成 + XSS 修補。本次修正 Google 2FA 登入後 redirect 到 Safari 的 bug。ChapterlyCore 118 tests，全綠。

## ✅ 2026-06-18 完成

- **`27ea497` fix(core)** — `NavigationPolicy.isGoogleDomain()`：支援 Google 國家代碼 TLD（`google.com.tw`、`google.co.jp` 等）+ `googleapis.com`。Google 2FA 登入後 `accounts.google.com.tw` 的 SetSID redirect 不再被送往 Safari。+ 2 新 tests。
- **`7afa5bc` fix(webview)** — 對 Google 域名使用 `allowWithoutTryingAppLink` policy 防止 Universal Links 劫持；加入 `#if DEBUG` 導航決策 log（`[NAV]` 前綴）。

## ✅ 2026-06-17 完成（commit 順序）

- **`51e1305` fix(ci)** — verify.sh 處理 `build.db` race：`swift test` exit code 以 `set +e` + `PIPESTATUS[0]` 捕捉，非零但無真實 test failure 時記錄並繼續，不再因 SWBBuildService I/O 碰撞中斷 hook。
- **`51e1305` Task 1** — `SourceKind.swift`：`enum SourceKind(.patreon/.googleDocs)` + `SourceProvider` struct + `SourceRegistry`（patreon startURL/icon + googleDrive startURL/icon）+ 3 tests。
- **`e302853` Task 2** — `Models.swift`：`LocalCollectionModel.sourceKindRaw`（default `.patreon`）+ computed `sourceKind` get/set；`LocalChapterModel.contentHTML: String?`；SwiftData lightweight migration（有 default，無需 SchemaMigrationPlan）+ 2 tests。
- **`d6054a7` Task 3** — `URLNormalizer.googleDocID()` + `canonicalGoogleDocURL()` + 3 tests。
- **`95d22c2` Task 4** — `GoogleDocsChapterSplitter`：`split(html:docID:docTitle:)` → `ImportedCollection`；h1→h2→h3 heading split；TOC filter（目錄/目次/contents/table of contents）；no-heading fallback；`sanitize()`（script/style/事件處理器）；HTML fixtures（3-chapter/TOC+2-chapter/no-heading）+ 5 tests。
- **`6bf9c57` Task 5** — `LibraryStore.applyDocImport(_:)`：找或建 `.googleDocs` collection，upsert chapters（URL 為 key），`context.save()`；`orderIndex = i`（0-based 閱讀順序）+ 3 tests。
- **`55549ef` Task 6** — `NavigationPolicy`：允許 `google.com` / `.google.com` / `.googleusercontent.com` / `.gstatic.com` in-app + 2 tests。
- **`064a8e6` Task 7** — `WebViewModel.isOnGoogleDocPage`（`docs.google.com` + `/document/d/` path）；`fetchGoogleDocHTML()`（JS `fetch` → `/mobilebasic`，`credentials:'include'`）。
- **`de4b3be` Task 8** — `AppEnvironment.importGoogleDoc(from:)`：URL → docID → fetch HTML → split → `applyDocImport` → `importedCountThisSession`。
- **`e8c0a04` Task 9** — `WebCollectionBanner`：Google Doc 偵測分支（`isOnGoogleDocPage` → "Import all chapters" button，`smoke.importChaptersButton`）；Patreon 分支改為 `else if`。
- **`131b877` Task 10** — `BrowseView` source selector：`HStack` ForEach `SourceRegistry.all`，border button，`smoke.sourceEntry.<kind>` accessibility ID；`.onAppear` URL 改用 `SourceRegistry.patreon.startURL`。
- **`ce984d6` Task 11** — `ReaderView`：`renderingStoredHTML` flag；`wrappedHTML(_:)` 包 CSS vars（fontSize/lineSpacing）；`open(_:)` branch — `contentHTML` 有值走 `loadHTMLString`，無值走 `env.reader.load(url)`；`syncCurrentChapter` guard。
- **`59886d1` Task 12** — `LibraryView`：collection row 加 leading source icon（`SourceRegistry.provider(for:).iconSystemName`，`smoke.collectionSourceIcon`）。
- **`9ee0793` Task 13** — `CollectionTOCView`：refresh button 包 `if collection.sourceKind == .patreon`（Google Docs collections 沒有 refresh）。
- **`a64fd6d` fix(security)** — `sanitize()` XSS 補強：新增 `href`/`src` 的 `javascript:`/`data:` URI strip（雙引號 + 單引號各一道 regex）；`<meta>` tags wholesale 移除（防 `http-equiv="refresh"` redirect）+ 1 新 test（`testSanitizeStripsJavascriptHrefsDataSrcAndMeta`）。

## ✅ Suggested task from Claude — completed this session (`a64fd6d`)

原始建議文字（已完成，供參考）：

**Add sanitize() XSS hardening for javascript: URLs and data: URIs**

In /Users/shane_yeh/Projects/Chapterly on branch feat/google-docs-import, the HTML sanitizer in GoogleDocsChapterSplitter.sanitize() (ChapterlyCore/Sources/ChapterlyCore/GoogleDocsChapterSplitter.swift) strips `<script>`/`<style>` tags and inline event handlers (onclick= etc.), but it does NOT strip:
1. href="javascript:..." on anchor tags
2. src="data:..." on img/iframe tags
3. The `<meta>` tag (which can set http-equiv refresh or CSP)

These are rendered via WKWebView loadHTMLString with a docs.google.com baseURL, so javascript: hrefs are a real XSS vector even without `<script>`. The fix should add regex passes to sanitize() that:
- Strip href="javascript:[^"]*" (and single-quoted variant)
- Strip src="data:[^"]*" on any tag (and single-quoted variant)
- Strip `<meta>` tags wholesale

Add a unit test in ChapterlyCoreTests/GoogleDocsChapterSplitterTests.swift covering each new strip rule.

**→ Done: commit `a64fd6d`. All three vectors patched. New test `testSanitizeStripsJavascriptHrefsDataSrcAndMeta` added. 114/114 tests green.**

## ⏳ 待完成（手動）

### Task 14 — 模擬器手動驗證（使用者執行）
1. 開 iOS Simulator，手動登入 Google 帳號（Cloudflare/Google OAuth = 手動步驟）。
2. Browse tab → 選 "Google Drive" source → 導航到 shared Google Doc。
3. 確認頂部出現「Import all chapters」banner。
4. 點 Import → Library 確認出現新 collection（書本圖示 = `doc.richtext`）。
5. 進 collection → 確認 TOC 章節順序正確（閱讀順序 0, 1, 2…）。
6. 點第一章進 reader → 確認文章正常顯示（stored HTML 路徑）。
7. 前後章 prev/next navigation 正確。
8. 書籤：TOC 行 + reader top bar 同步切換；relaunch 後書籤保留。
9. （可選）跑 `./scripts/smoke-auto.sh` 做 8 步回歸（需先登入 Patreon + 設 `.env` 的 `SMOKE_TEST_URL`）。

## ⚠️ 可選改進（不阻擋 merge，code review 旗標）
- `ChapterOrdering.sortKey` Google Doc URL fallback `(1, orderIndex)` 加一行說明 comment。
- `applyDocImport` 目前不刪除 reimport 後消失的章節（shrink case）——加 TODO 或處理。
- `fetchGoogleDocHTML` 超大 doc（>5MB）加 size warning log。
- `BrowseView.activeKind` 與實際 URL 目前不同步（使用者可手動導航離開）。
- `importGoogleDoc` 的 `applyDocImport` 錯誤目前被 `try?` 吞掉——考慮 log 或 toast。
- `SourceRegistry.provider(for:)` fallback 可加 `assertionFailure`。

## ⚡ 接手要做的事
1. **Task 14 手動模擬器驗證**（見上）。
2. **PR 準備**（使用者說 go 才做）：push `feat/google-docs-import`，開 PR target `main`，body 摘要 14 tasks + 各自 commit。

## ⚠️ 注意事項
- **Patreon 登入必須保留**：不要 erase/reset/uninstall 模擬器。
- Google OAuth / Cloudflare / CAPTCHA = 手動使用者步驟，agent 不自動化。
- `build.db` IOERR 不是程式錯誤，是 SWBBuildService race（verify.sh 已有 guard）。
- `GoogleDocsChapterSplitter.split()` 用 `/mobilebasic` 路由，不用 `/export`（403）、不用 postMessage（`PayloadValidator.forbiddenKeys` 擋住）。
- `orderIndex = i`（0-based 閱讀順序）+ default `sortDirection: .oldestToNewest` → 正確 TOC 及 prev/next。若改 `newestToOldest` 或用 `N-1-i` 會讓 prev/next 反向。
- Google Docs collection 無 refresh（`sourceKind == .patreon` guard 在 TOC view）。

## 📁 本次新增/修改的檔案
**ChapterlyCore（純 Swift Package，可 unit test）：**
- `ChapterlyCore/Sources/ChapterlyCore/SourceKind.swift`（新增）
- `ChapterlyCore/Sources/ChapterlyCore/Models.swift`（+sourceKindRaw/contentHTML）
- `ChapterlyCore/Sources/ChapterlyCore/URLNormalizer.swift`（+googleDocID/canonicalGoogleDocURL）
- `ChapterlyCore/Sources/ChapterlyCore/GoogleDocsChapterSplitter.swift`（新增）
- `ChapterlyCore/Sources/ChapterlyCore/NavigationPolicy.swift`（+Google allowlist）
- `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift`（+applyDocImport）
- `ChapterlyCore/Tests/ChapterlyCoreTests/SourceKindTests.swift`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/ModelMigrationTests.swift`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/URLNormalizerGoogleDocsTests.swift`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/GoogleDocsChapterSplitterTests.swift`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/GoogleDocsImportStoreTests.swift`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/NavigationPolicyGoogleTests.swift`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/gdoc-33chapter.html`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/gdoc-42chapter-toc.html`（新增）
- `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/gdoc-noheading.html`（新增）

**App target（build 驗證，無 unit test）：**
- `App/WebView/WebViewModel.swift`（+isOnGoogleDocPage/fetchGoogleDocHTML）
- `App/AppEnvironment.swift`（+importGoogleDoc）
- `App/Features/Shared/WebCollectionBanner.swift`（Google Doc 分支）
- `App/Features/Browse/BrowseView.swift`（source selector）
- `App/Features/Reader/ReaderView.swift`（stored HTML 路徑）
- `App/Features/Library/LibraryView.swift`（source icon）
- `App/Features/Library/CollectionTOCView.swift`（Patreon-only refresh）

**CI：**
- `scripts/verify.sh`（build.db race guard）

---

## WebKit / WebContent device-log triage

Lines observed in device logs during development. Grouped by action required.

### Benign — no action needed

- `Could not create a sandbox extension for '…Chapterly.app'` — standard WKWebView message on sideloaded/dev builds; not present in App Store builds.
- `xpc_user_sessions_get_foreground_uid() failed … Operation not permitted` — XPC session bootstrap noise on simulator and dev-signed device; harmless.
- `Unable to hide/filter query parameters (missing data)` — WebKit internal URL logging; no impact on functionality.
- `Process took N seconds to launch` (multi-second) — cold-start cost of WKWebView on first launch; subsequent launches are faster.

### Content-side — not app-fixable

- `makeImagePlus … 'WEBP' … err=-50` — WebKit failing to decode some of Patreon's WebP images. Does not affect chapter text; page renders without those images.

### Actionable signal

- `WebProcessProxy::didBecomeUnresponsive` — correlates with the heavy collection-import crawl (240-round scroll loop over a ~200 MB collection DOM in the offscreen `refresher`). The code already frees the DOM after import (`AppEnvironment.swift` near `runCollectionImport`). If this becomes frequent on very large collections, consider lowering the round cap in `CollectionImport.js` (currently 240) after measuring with the specific collection.

## 🔗 相關資源
- 實作計畫：`docs/superpowers/plans/2026-06-15-google-docs-import.md`（gitignored）
- Simulator 操作手冊：`SIMULATOR_PLAYBOOK.md`
- Standard verification：`./scripts/verify.sh`
- Smoke auto（需登入 + `.env`）：`./scripts/smoke-auto.sh`
