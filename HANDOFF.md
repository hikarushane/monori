# HANDOFF

> 上次 session: 2026-06-19（drawer retract 診斷 — 問題已自行修復）
> 下次接手請從「接手要做的事」開始

## 狀態
Feature branch `feat/google-docs-import`（off `main`）。Plan 全部完成（Task 1–5）。ChapterlyCore 125 tests，全綠。
- 測試/建置狀態：✅ 綠（跑 `./scripts/verify.sh` 確認）
- 分支 ＠ 最後 commit：`feat/google-docs-import @ 485c91c`
- 工作樹：`build/smoke/` 工件 unstaged（截圖/log，不影響 code）

## ✅ 本次完成（2026-06-19）

- **Bug 4 根本原因確認**：`ReaderRuleset.css` dark-mode `body { background-color: #1c1b19 !important }` 被 `injectionScript()` 注入 Google Docs 章節，蓋掉 `wrappedDocument` 的白底
- **修復 gray veil**：`applyReaderTreatment()` 對 `renderingStoredHTML == true` 跳過 `injectionScript()`（`App/Features/Reader/ReaderView.swift`）
- **WKWebView opacity 修復**：`webView.isOpaque = true` + `.backgroundColor = .systemBackground`（`App/WebView/WebViewModel.swift`）
- **contentInsetAdjustmentBehavior**：`.fullScreenCover` 中改為 `.never`（`App/WebView/PatreonWebView.swift`）
- **Dark mode 支援**：`wrappedDocument()` 改用 `Canvas`/`CanvasText` + `color-scheme: light dark`（`ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift`）
- **Google Docs inline color 覆蓋**：加 `* { color: CanvasText !important; background-color: transparent !important; }` 蓋掉 Google Docs 每個 `<p>/<span>` 的 hardcoded `#000000`/`#ffffff`（`ReaderStyler.swift`）
- **單元測試更新**：`testWrappedDocumentSupportsLightAndDarkScheme` 改斷言 `"light dark"` / `Canvas` / `CanvasText`（`ChapterlyCore/Tests/ChapterlyCoreTests/ReaderStylerTests.swift`）
- 使用者實機驗證：light mode 白底深字 ✅、dark mode 深底白字 ✅

## ✅ 本次完成（2026-06-19 Task 3 + 4）

- **Task 3**：`PatreonWebView.makeUIView()` 的 content-tap `UITapGestureRecognizer` 改為只在 `onContentTap != nil` 時安裝（`App/WebView/PatreonWebView.swift` commit `c6ec681`）
- **Task 4**：HANDOFF.md 新增正確 Google AutoFill 說明（非 bug，iOS QuickType heuristic，無公開 API 可強制）；補 Console log 條目（`0.5` = 網頁 JS、`unsafeForcedSync` = 系統框架、`RTIInputSystemClient` / `WebContent` 啟動成本）（commit `4ab9ea6`）
- `verify.sh` 124/124 ✅

## ✅ 本次完成（2026-06-19 Task 5）

- **Task 5**：`AppEnvironment` 的 `googleBrowse` + `refresher` 改為 `@ObservationIgnored` backing optional + computed property（`lazy var` 在 `@Observable` class 不支援）；`init()` 只 wire `browse`/`reader`——冷啟動 WKWebView 從 4 降為 2（commit `1cf69f5`）

## ✅ 本次完成（2026-06-19 Drawer 診斷 session）

**問題**：Library 看完文章後回 Browse → Google Drive 按漢堡選單，drawer 開了 ~0.5s 後自動縮回。

**診斷工具新增**（全部 `#if DEBUG` + `isSmokeMode`，不影響 production）：
- `ChapterlyCore/Sources/ChapterlyCore/Assets/DrawerDiagnostics.js`：頁面側事件 reporter（`resize`/`visibilitychange`/`focus`/`blur`/`pageshow`/`pagehide`/`scrim-added`/`scrim-removed`）（commit `b070310`）
- `ChapterlyCore/Sources/ChapterlyCore/JSAssets.swift`：加 `drawerDiagnostics` 屬性（commit `b070310`）
- `App/WebView/WebViewModel.swift`：加 `DrawerDiagShim` + `WKUserScript` 注入（commit `b070310`）
- `App/WebView/PatreonWebView.swift`：native `makeUIView`/`updateUIView` bounds log（commit `a59239c`）
- `ChapterlyCore/Tests/ChapterlyCoreTests/JSExtractionTests.swift`：加 `testDrawerDiagnosticsScriptLoadsAndPostsMessages`（commit `b070310`）

**Bug 修正**（commit `485c91c`）：
- `DrawerDiagnostics.js` 的 `scrim-removed` 偵測用 `getBoundingClientRect()` 在 detached DOM 上回 zeros → 改為標記 `data-chap-scrim="1"` attribute
- `DrawerDiagShim` log line 中 `dpr` 缺 `privacy: .public`

**診斷結果**（一次完整 repro：Library → 章節 → 關閉 reader → Browse → Google Drive → 漢堡）：
- Drawer **沒有**縮回（bug 不再重現）
- 整個 fullScreenCover 週期中，Google Drive 頁面**沒有** `resize` 事件
- `updateUIView bounds={0,0}` 的 transient 確實發生，但 WebKit 不把它傳給頁面 JS
- 結論：**commit `1cf69f5`（lazy googleBrowse init）間接修復了此 bug**。原因：`googleBrowse` WKWebView 現在一旦建立就保持存活，fullScreenCover 不再觸發重建 → 不再有 zero-size viewport pass → Google Drive drawer 無法被迫縮回

**下一步**：bug 已修復，診斷 code 留在 `#if DEBUG` + smoke 條件下（對 production 零影響），不需另行 revert。

## 🔄 進行中

無。Plan 全部完成，drawer bug 已確認修復。

## 🚧 試過但行不通（避免重踩）

- **`webView.scrollView.backgroundColor = .systemBackground`** → WKWebView 每次 `loadHTMLString` 後自行 reset `scrollView.backgroundColor`，UI layer 正確但 veil 仍在；真正根因是 CSS injection，不是 UIKit layer
- **`color-scheme: light` + `background: #ffffff` 強制白底** → 解決了 gray veil，但 dark mode 下顯示白底黑字，使用者要求支援 dark mode 自適應
- **`[READER-DIAG3]` 放在 `injectionScript()` 之前** → 診斷 JS 先執行，顯示「白底」是注入前狀態，誤導分析；診斷要放在注入後

## ⚡ 接手要做的事（優先順序）

1. **裝置回歸**（使用者手動，verify.sh 無法驗）：
   - Reader 章節中央點擊仍切換 chrome
   - Browse 頁面點擊不觸發任何行為
   - Browse → Google Drive → Google 登入正常
   - 集合頁 → 重新整理章節正常
   - 冷啟動 `WebContent` 進程行數減少（Xcode console）
   - **Library → 章節 → 關閉 reader → Browse → Google Drive → 漢堡選單不縮回** ✅（已由 Simulator 驗證）
2. **下一個 feature**：與使用者討論 `feat/google-docs-import` 的後續工作或 PR 準備

## ⚠️ 注意事項

- `ReaderRuleset.css`（`ChapterlyCore/Sources/ChapterlyCore/Assets/`）**不需要修改**：其 dark-mode body rule 是為 Patreon 頁面設計，只要 Google Docs 章節不注入即可
- Patreon 登入狀態需保留，不能 erase/reset Simulator
- `build/smoke/current-screen.png` 是截圖工件，不需 commit

## 已知限制

- **Google 登入只顯示 🔑「密碼」鍵、鍵盤上方不自動列出帳號 — 非 app bug，AutoFill 正常運作。**
  實機驗證：點該鑰匙鍵會列出已存的 Google 帳號（AutoFill 已生效）。鍵盤上方的
  inline 帳號建議列是 iOS QuickType 的啟發式行為，依頁面 `autocomplete` 屬性與
  Keychain 域名比對決定，**無公開 API 可強制顯示**。app 設定皆正確：持久
  `WKWebsiteDataStore.default()`、stock `WKWebView`、無 `inputAccessoryView` 覆寫、
  `CardTreatment.js` 在登入頁完全 inert（`<style>` 只 scope 到 `[data-tag="post-card"]`，
  `scan()` 只查該 Patreon selector，click handler 對 input/textarea/select 直接 bail）。
  （更正 2026-06-18 的「Simulator-only」說法：該 bug 在實機同樣出現，且其實不是 bug。）

## 📁 本次修改的檔案

- `App/Features/Reader/ReaderView.swift` — `applyReaderTreatment()` 跳過 stored HTML 的 `injectionScript`
- `App/WebView/WebViewModel.swift` — `webView.isOpaque`/`backgroundColor`/`scrollView.backgroundColor`；drawer 診斷：`DrawerDiagShim` + `JSAssets.drawerDiagnostics` 注入（`#if DEBUG` + `isSmokeMode`）
- `App/WebView/PatreonWebView.swift` — `scrollView.contentInsetAdjustmentBehavior = .never`；drawer native bounds log（`#if DEBUG` + `isSmokeMode`）
- `ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift` — dark mode CSS (`Canvas`/`CanvasText`/`*` color override)
- `ChapterlyCore/Tests/ChapterlyCoreTests/ReaderStylerTests.swift` — 更新 dark mode 斷言
- `ChapterlyCore/Sources/ChapterlyCore/Assets/DrawerDiagnostics.js` — 新增：頁面側 drawer 診斷腳本（`#if DEBUG` + `isSmokeMode` 注入）
- `ChapterlyCore/Sources/ChapterlyCore/JSAssets.swift` — 新增：`drawerDiagnostics` 屬性
- `ChapterlyCore/Tests/ChapterlyCoreTests/JSExtractionTests.swift` — 新增：`testDrawerDiagnosticsScriptLoadsAndPostsMessages`

## Console log 噪音分類（非 bug，勿再追）

（繼承自 2026-06-18）
- `CHHapticPattern … hapticpatternlibrary.plist … No such file`：Simulator 無觸覺硬體。
- `'WEBP' … initImage failed err=-50`：Simulator WebP 解碼器；實機正常顯示圖片。
- `Could not register system wide server: -25204`、`_AXAddToElementCache`、重複的
  `WebKit.axbundle`/`WebCore.axbundle` class、`Unable to hide query parameters`：WebKit/AX 噪音。
- `Unable to simultaneously satisfy constraints`（`_UIKBCompatInputView`、`_UIButtonBarButton`）：
  系統鍵盤 + SwiftUI `.toolbar` 內部，會自動 recover，無可見影響。
- `web-browser-engine` entitlement / `XPCConnectionTerminationWatchdog` / `No such process`：
  任何第三方 app 嵌入 `WKWebView` 都會有（只有 Safari 持有該 entitlement）。
- `CoreData … incremental_vacuum` / `WAL checkpoint`：我們的 SwiftData，正常；代表 import 已存檔。
- `[NAV] …`：我們自己的 debug log。
- `0.5`（單獨一行、無前綴）：**不是我們的 log**。`App/` 內唯一的 `print(` 是四行 `[NAV]`
  （`WebViewModel.swift`）。`0.5` 是網頁自身 JavaScript `console.log`，因 Xcode debugger 附著
  而出現在 console（Patreon `/home` 頁的 JS）。
- `Potential Structural Swift Concurrency Issue: unsafeForcedSync called from Swift Concurrent context.`：
  系統框架（SwiftUI-Observation / WebKit）發出，**非我們的 code**——`App/` 內無任何 `.sync` /
  `assumeIsolated` / `DispatchSemaphore` / `.wait()` / `RunLoop`（已 grep 驗證）。啟動時偶發一次，無可見影響。
- `RTIInputSystemClient … Can only set suggestions for an active session` / `requires a valid sessionID` /
  `Snapshotting a view (UIKeyboardImpl) … requires afterScreenUpdates:YES`：鍵盤輸入 session 噪音，
  第三方 app 嵌 `WKWebView` 常見；與 Bug 3 的 inline 建議列無直接因果（已移除登入頁多餘的 tap 手勢以降低 churn）。
- `WebContent/GPU/Networking process took 7–10 seconds to launch`：實機冷啟動成本，部分源於
  `AppEnvironment.init` 一次建立四個 `WKWebView`（browse/googleBrowse/reader/refresher）。
  非 bug；若要改善見 plan 的 Task 5（可選，預設不做）。

## 🔗 相關資源

- Plan（本次）：`docs/superpowers/plans/2026-06-19-reader-veil-autofill-console-fixes.md`
- Drawer 診斷計畫：`docs/superpowers/plans/2026-06-19-google-drive-drawer-retract-fix.md`（gitignored）
- 實作計畫（Google Docs import）：`docs/superpowers/plans/2026-06-15-google-docs-import.md`（gitignored）
- Simulator 操作手冊：`SIMULATOR_PLAYBOOK.md`
- Standard verification：`./scripts/verify.sh`
- Smoke auto（需登入 + `.env`）：`./scripts/smoke-auto.sh`
