# MEMORY
> 這個 project 的長效記憶，每次 session 累積更新
> 最後更新：2026-06-11

## 專案概覽
Chapterly 是 iOS SwiftUI app，讓用戶在 Patreon WKWebView 中閱讀連載小說，自動偵測章節集合、匯入章節列表、追蹤閱讀進度。核心技術：SwiftUI + SwiftData + WKWebView + JavaScript injection。目標：完整 MVP 可用。

## 架構決策
| 決策 | 選擇 | 原因 | 狀態 | 日期 |
|------|------|------|------|------|
| 章節資料儲存 | SwiftData | iOS native，無需 server，schema migration 內建 | active | 2026-06 |
| 進度追蹤 | JS ProgressTracker.js injection + WKScriptMessageHandler | 不需 native scroll view，直接讀 DOM scroll | active | 2026-06 |
| 章節 import | JS CollectionImport.js postMessage → Swift PayloadValidator | 在 WebView context 執行 DOM 解析，結果傳回 Swift 驗證 | active | 2026-06 |
| Scroll 回復 | enforceScrollScript interval 4s/400ms | Patreon 自帶 auto-scroll 會搶奪控制，需 interval 贏回 | active | 2026-06-11 |

## 規範
### Patreon DOM
- Collection page：post card 的 teaser text 通常是 anchor 的 sibling，不在 anchor 內
- `excerptFromCard()` 三層搜尋：anchor 內 → anchor 文字行 → 向上爬 ≤4 層父節點，遇 `distinctPostLinkCount > 1` 停止
- Collection DOM order：最新 post = DOM 第一個 = `domOrder: 0`

### 章節排序
- `orderIndex` 代表 Patreon DOM 位置（0 = 最新）
- Story order（閱讀順序）= descending orderIndex（orderIndex 大 = 舊 = 故事前面）
- `neighbors()` 用 descending orderIndex：`previous` = 更舊章節，`next` = 更新章節

### 標題清理
- `looksLikeBodyText()` 只檢查 `。`（中文句號）和長英文中的 `. `
- 不檢查 `？！…」』`——這些符號正常出現在中文章節標題
- `isProbablyContaminatedTitle()`：2+ 行 OR >100 chars OR body text
- `firstLineIsTitle`：≤100 chars AND NOT body text

### 進度儲存
- `ProgressTracker.js` 只在 `__chapterlyUserInteracted === true` 後存 progress
- `touchstart` / `wheel` 事件設 flag
- `enforceScrollScript` 每次執行先 reset `__chapterlyUserInteracted = false`

### SPA Navigation
- Patreon 是 SPA：article-to-article navigation 不觸發 WKWebView `didFinish`
- 用 `.onChange(of: env.reader.currentURL)` 觀察 URL 變化 → `syncCurrentChapter(to:)`

## 踩過的坑
- **Linker error after derived data corrupt**（2026-06-11）：刪舊 test bundle 後 `ld: symbol(s) not found for ImporterChapterPayload.init`，XCTest 快取舊 binary → `find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Chapterly-*" -exec rm -rf {} +`
  📍 出現位置：clean rebuild 後 `xcodebuild test`

- **`xcodebuild clean` 找不到 destination**（2026-06-11）：`xcodebuild clean -scheme Chapterly` 失敗，`-destination 'iPhone 17'` 只對 `test` command 有效 → 改用刪 DerivedData workaround

- **looksLikeBodyText 誤判中文標題**（2026-06-11）：原本檢查 `？！…」』` → 正常章節標題如「那妳呢？」被誤判為 body text → 縮減至只檢查 `。`

- **Progress 被 Patreon auto-scroll 污染**（2026-06-11）：Patreon 頁面 load 後自帶 scroll，ProgressTracker 存入接近 1.0 的值 → 下次開文章恢復到底部 → 加 user-interaction gate 解決；但舊污染值需手動滾一下覆蓋

- **新測試未被 XCTest 發現**（2026-06-11）：touch 測試檔案（`touch ChapterMapMergerTests.swift`）強制 recompile 才被 runner 找到

## 排除的方向
- 自動化 Patreon 登入：CAPTCHA/2FA/session token，法律與安全風險
- 用 `scrollApplied: Bool` guard 防止重複 scroll：Patreon 自帶 scroll 在 guard 後才執行，無效 → 改用 enforceScrollScript interval

## 環境 / 依賴
- XcodeGen：`xcodegen generate` 後需 `xcodebuild -list -project Chapterly.xcodeproj` 驗證
- 測試 fixture HTML 放 `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/`
- Smoke test artifacts 寫入 `build/smoke/`

## 未解決的問題
- [ ] 舊 chapter 的 `excerpt` 欄位是 nil，需用戶手動重新 import collection 才填入 teaser
- [ ] `smoke-auto.sh` 尚未在此批改動後跑過
