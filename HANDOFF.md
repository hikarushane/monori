# HANDOFF

> 上次 session: 2026-06-12（session 3 延續）
> 下次接手請從「接手要做的事」開始

## 狀態
6 個 bug 全部修完；verify.sh 85/85 pass。Cloudflare 驗證已由使用者手動解掉，
第一輪 4 修後 smoke-auto 7/7；第二輪（Load more + 左滑返回）修後 smoke 結果見 auto-report.md。

## ✅ 第三輪修復（2026-06-12）
- **Bug 7（創作者頁點擊無反應）**：兩個 root cause——(a) 沒有 WKUIDelegate，target=_blank 連結被 WKWebView 靜默忽略 → 加 `createWebViewWith` 走 NavigationPolicy 原地載入；(b) Reader CSS（藏 nav/aside/footer、article 42em）連 foreign 頁都注入 → foreign 改跑 `removalScript()`
- **Bug 8（post card 體驗）**：新 `CardTreatment.js` user script（Browse/Reader 都注入）：`[data-tag="post-card"]` 整卡可點（點非互動區 → 觸發 title link）、卡內文字不可選取、隱藏中英文 Show more 按鈕、teaser 容器加 mask 漸層淡出；MutationObserver（300ms throttle）跟隨 SPA 重渲染。TDD：`post_cards.html` fixture + `testCardTreatmentMakesCardsClickableAndCollapsesTeasers`

## ✅ 第二輪修復（2026-06-12）
- **Bug 5（Load more 沒吃到）**：matcher 只認英文 + 點擊前置於捲動且穩定計數不看按鈕 → 中文「載入更多」永遠不點、點了也會在網路延遲中提前退出。修：中英 matcher（button/[role=button]、aria-label fallback）、捲底後找按鈕、點擊後等 1200ms、結束條件 = **無按鈕 AND 連結數穩定 3 輪**、上限 240 輪。TDD：`collection_page_load_more.html`（中文按鈕 + 1.5s 延遲）RED→GREEN
- **Bug 6（Browse 左滑不返回）**：WKWebView 原生手勢不支援 SPA same-document entry。修：關原生手勢，`PatreonWebView` 裝左緣 `UIScreenEdgePanGestureRecognizer`（translation>60pt）→ `goBack()`

## ✅ 本次完成
- **Bug 1（scroll 回歸）**：root cause 是 `1f29d51` 在 `applyReaderTreatment()` 加了 `guard foreignPageTitle == nil else { return }`，foreign 頁面從此不跑 `enforceScrollScript`；另外 `syncCurrentChapter` 同 id 早退路徑在 SPA 返回已知章節時也跳過 treatment（SPA 無 didFinish）。修法：enforce 永遠執行（foreign 釘在頂部、known 還原進度）；found 分支 `wasForeign` 時重新套用 treatment；foreign 分支進入時就套用，並用 `foreignPageKey`（postID）防同頁 URL 重寫重複釘頂
- **Bug 2（Browse banner 殘留）**：root cause 不是 reselect 沒清 `detectedCollection`（KVO 本來就清），是 `runCollectionDetect()` 在 SPA 返回首頁時對舊 DOM 跑、偵測結果又把 banner 設回來。修法：`runCollectionDetect()` 限定 post 頁（`URLNormalizer.patreonPostID != nil`）+ `onCollectionLink` 收訊時再驗一次 `isOnPostPage`（擋 race）
- **Bug 3（Browse menu 可拖動）**：全 codebase 沒有 `.onMove`/`.draggable`——是 WKWebView 給 `<a>` 的原生 drag interaction。修法：user script `dragstart` preventDefault（兩個 WebViewModel 都吃到）
- **Bug 4（import 只匯入可見章節）**：`CollectionImport.js` 重寫成 async function body（`callAsyncJavaScript`）：捲動展開 lazy 清單直到 post 連結數穩定 3 輪（每輪 500ms、上限 60 輪），逐輪累積擷取（容忍虛擬化清單）、`domOrder` = 首見順序，最後一次性 postMessage。按鈕改「Import all chapters」+ 匯入中 ProgressView；alert 文案同步更新；`runCollectionImport()` 改 async 回傳數量
- TDD：新 fixture `collection_page_lazy.html`（捲動後才追加 3 個 post）+ `testCollectionImportLoadsLazyContentBeforeScraping`，RED→GREEN；測試 harness 改用 `callAsyncJavaScript`
- `./scripts/verify.sh`：build ✓ + **84/84 tests pass**

## 🚧 卡住的事：Cloudflare 人類驗證
smoke-auto 兩次都在 `import` 步驟 fail（`no_post_links_found`）。截圖證實 Patreon 對 Simulator 出了 **Cloudflare「驗證您是人類」checkbox**（頁面 title「請稍候...」、collection 清單永遠不渲染）。CAPTCHA 屬於手動步驟（CLAUDE.md 禁止自動化）。

## ⚡ 接手要做的事（優先順序）
1. **使用者手動**：開 Simulator → 在 Patreon 頁面勾 Cloudflare「驗證您是人類」→ 確認頁面正常顯示
2. 重跑 `./scripts/smoke-auto.sh`，預期 7/7（上次失敗純粹是 CAPTCHA 擋住）
3. 手動驗證 4 個修復：①Library 集合點進文章不再捲到底（含從 collection 頁點進去）②Browse 開文章→按 Browse tab 回首頁，banner 消失 ③Patreon 左上 menu 項目不可拖動 ④collection 頁按「Import all chapters」，匯入數 = 整個 collection 章節數（會自動捲動，等它跑完）
4. **README.md:48 待使用者確認後更新**：「Import visible chapters」→「Import all chapters」，並補一句「匯入會自動捲動載入整個清單」（README gate：需使用者同意才改）
5. 舊章節 `excerpt` nil → 現在重按一次 import 就會全部補齊（Bug 4 修復順帶解決）

## ⚠️ 注意事項
- smoke artifacts（build/smoke/*）目前是失敗 run 的狀態，等 CAPTCHA 解掉重跑後再 commit
- `JSExtractionTests` 每個 import 測試現在 ~2s（捲動穩定判定），整包 21s 屬正常
- commit 順序刻意拆成可獨立 build 的三份：reader fix → browse/webview fix → import feature

## 📁 本次修改的檔案
- `App/Features/Reader/ReaderView.swift` — enforce 不再被 foreign guard 擋掉；wasForeign 重套 treatment；foreignPageKey
- `App/WebView/WebViewModel.swift` — `isOnPostPage`、detect gate、dragstart suppressor、async `runCollectionImport`
- `App/AppEnvironment.swift` — `onCollectionLink` 收訊時驗 post 頁
- `App/Features/Shared/WebCollectionBanner.swift` — Import all chapters、importing 狀態、alert 文案
- `App/Features/Library/LibraryView.swift` — 空狀態提示文字同步
- `App/SmokeAutopilot.swift` — `await runCollectionImport()`
- `ChapterlyCore/Sources/ChapterlyCore/Assets/CollectionImport.js` — 全部重寫（async 展開迴圈）
- `ChapterlyCore/Tests/ChapterlyCoreTests/JSExtractionTests.swift` — callAsyncJavaScript harness + lazy 測試
- `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/collection_page_lazy.html` — 新 fixture

## 🔗 相關資源
- `scripts/verify.sh` — automated build + unit tests
- `scripts/smoke-diagnostics.sh` — manual smoke test with Patreon login
- `scripts/smoke-auto.sh` — full smoke loop（需先 Simulator 手動登入 Patreon + 解 CAPTCHA）
