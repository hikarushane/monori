# HANDOFF

> 上次 session: 2026-08-24
> 下次接手請從「接手要做的事」開始

## 狀態
修復 AO3 Reader URL lookup regression：`LibraryStore.chapter(withPageURL:)` 現在會 canonicalize AO3 chapter URL，並對舊的非 canonical 儲存 URL 做 defensive fallback，避免已匯入章節被誤判為 foreign page 而移除 Reader CSS。
- 測試/建置狀態：✅ AO3 regression tests 2/2 過；✅ `swift test --package-path MonoriCore`（XCTest 334/334 + Swift Testing 13/13）過；⚠️ `verify.sh` 完整跑會在既有 design guard 問題卡住（見下方注意事項）
- 分支＠最後 commit：`main` ＠ `9400f01`（本輪未 commit，工作樹 dirty）
- 工作樹：dirty，這次 dark-mode 修復跟上一輪 session 的主題切換滑塊重構疊在同一個未 commit 工作樹裡，尚未拆分

## ✅ 本次完成
- 用 `superpowers:systematic-debugging` 追到 AO3 chapter URL 的匯入、lookup 與 Reader foreign-page removal data flow；確認不是 CSS、WebKit timing 或 parser 問題
- 新增 `testChapterWithPageURLMatchesAO3Chapter`，涵蓋 canonical URL、query/fragment、第二章與不存在章節；另補 `testChapterWithPageURLMatchesLegacyNonCanonicalAO3ChapterURL`，直接鎖住舊資料 stored-URL fallback
- 在乾淨 HEAD 的隔離 worktree 只套 regression test，確認修改前 1/1 失敗（lookup 回 nil）；套用最小 AO3 matching branch 後單測與完整 MonoriCore suite 全綠
- `graphify update .` 已執行，但因新 graph node 數少於既有 graph，工具 fail-closed 拒絕覆寫；未使用 `--force` 破壞既有 graph
- 用 `superpowers:systematic-debugging` 在 `applyReaderTreatment()` 注入診斷 JS，收集 5 個來源的 `prefers-color-scheme` / body 背景 / 文字色證據，確認 `prefers-color-scheme: dark` 在所有來源都正確 match、body 背景也都正確，問題出在中間容器背景與文字色兩層
- 修 `ReaderStyler.swift` 的 `wrappedDocument()`（Google Docs stored HTML）：`* { color: inherit !important }` 縮小作用域為 `body *`，避免覆寫 `<html>` 的 color；dark mode `body { color }` 加 `!important`
- 修 `AFFReaderRuleset.css`：加 6 層 `background-color: inherit !important` 祖先鏈級聯（仿 VocusReaderRuleset.css）+ dark mode body color `!important`
- 修 `ReaderRuleset.css`（Patreon/AO3）：加 `color-scheme: light dark` + dark mode body color `!important`
- 修 `ReaderStyler.swift` 的 `injectionScript()`：加 `clearAncestorBg()` JS，沿內容容器（`[data-tag="post-content"]` / `.patreon-post-content` / `article`）的祖先鏈精準清除 background-color，取代原本失敗的 CSS 級聯方案
- 移除 `ReaderView.swift` 的診斷 JS
- 使用者在模擬器實測確認：5 個來源、light/dark 兩種模式全部正常

## 🔄 進行中
無。

## 🚧 試過但行不通（避免重踩）
- 在 `ReaderRuleset.css` 對 `body` 到六層子孫套用跟 Vocus 相同的 `background-color: inherit !important` CSS 級聯 → Patreon 文章直接空白（light/dark 都是）。原因：Patreon 是 React SPA，暴力覆寫所有中間容器背景會連動破壞其版面必要樣式。改用 JS 只沿實際內容容器的祖先鏈精準清除背景，才沒有副作用（AFF 是傳統 server-rendered 頁面，同樣的 CSS 級聯沒有這個副作用，維持原寫法）。

## ⚡ 接手要做的事
1. `verify.sh` 目前會在 design guard 卡住：`App/Features/Shared/ThemeToggle.swift:27` 用了 `Capsule()`，Uguisu Zen 規範禁用該 shape token（上一輪 session 主題切換元件留下的），需要換成規範允許的 shape 才能讓 `verify.sh` 全線變綠
2. 待 design guard 修好後，完整跑一次 `./scripts/verify.sh` 確認全綠（本次只手動跑了 build + `swift test`，沒跑完整腳本）
3. Commit 本次 dark mode 修復 + 上一輪的 ThemeToggle 變更（工作樹是兩輪 session 疊在一起，建議拆成至少兩個 atomic commit：主題切換滑塊 / reader dark mode CSS 修復）

## ⚠️ 注意事項
- 工作樹是 dirty 的：這次 dark-mode 修復的檔案，跟上一輪 session 主題切換滑塊重構的檔案（`AppRootView.swift`、`CollectionTOCView.swift`、`LibraryView.swift`、`MonoriIcons.swift`、`LibraryQuery.swift`、新檔 `ThemeToggle.swift`）混在同一個未 commit 的工作樹裡，還沒分開
- `verify.sh` 完整跑會在 design guard 這步 FAIL（見上）；本次驗證只用 build + `swift test` 手動確認，不是跑完整 `verify.sh`
- 診斷用的 5 筆 log（`reader-dark-diag` category）是暫時性證據，已隨程式碼移除，不需要額外清理

## 📁 本次修改的檔案
- `MonoriCore/Sources/MonoriCore/LibraryStore.swift` — AO3 chapter URL canonical matching + 舊 URL fallback
- `MonoriCore/Tests/MonoriCoreTests/LibraryStoreTests.swift` — AO3 chapter lookup regression test
- `MonoriCore/Sources/MonoriCore/ReaderStyler.swift` — `wrappedDocument()` color inherit 縮小作用域；`injectionScript()` 加 `clearAncestorBg()`
- `MonoriCore/Sources/MonoriCore/Assets/ReaderRuleset.css` — 加 `color-scheme`、dark mode text color `!important`
- `MonoriCore/Sources/MonoriCore/Assets/AFFReaderRuleset.css` — 加背景祖先鏈級聯、dark mode text color `!important`
- `App/Features/Reader/ReaderView.swift` — 移除除錯用診斷 JS

## 🔗 相關資源
- 上一輪 session 的完整交接內容（Uguisu Zen 批次 0–7、Codex adapter）已被本次覆寫；如需查閱歷史脈絡，見 git blame 或 `MEMORY.md` 的架構決策/踩過的坑（該部分為累積式，未被覆寫）
