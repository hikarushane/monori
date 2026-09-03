# HANDOFF

> 上次 session: 2026-09-03
> 下次接手請從「接手要做的事」開始

## 狀態

CXC 與在水裡寫字（slashtw）兩個閱讀來源已完成並合併進 `main`。slashtw 的 Reader 模型在讀完版規後改為本地儲存每樓內文 HTML（ADR-0012 的 2026-09-03 修訂）。

- 測試/建置狀態：✅ 綠（`./scripts/verify.sh`，MonoriCore 519/519；合併前在 worktree、合併後在 main 各跑一次）
- 分支 ＠ 最後 commit：`main` ＠ `53cff6b`（merge `worktree-cxc-slashtw-sources`），已 push 到 GitHub `main/main`
- 工作樹：clean；feature worktree 與分支已移除

## ✅ 本次完成

- CXC：真實 selector、canonical reader URL（去語言前綴）、import-time 標題與作者；doc 再匯入會更新 collection 標題／作者。
- slashtw：真實 Waterfall selector；匯入前捲到底載入全部樓層（測試串 14/14）；每樓 `.card-content > div.content` 內文經 `HTMLSanitizer` 後存 `contentHTML`，reader 走 stored-HTML 路徑單章渲染；`.comments` 留言區與 Discuz `i.pstatus` 編輯戳去除。
- 新增共用 `HTMLSanitizer`（自 `GoogleDocsChapterSplitter` 抽出，擴充 iframe／object／embed 與未閉合 tag）。
- `ReaderView`：slashtw thread URL 不再被判 foreign page（無內文時的 fallback 路徑）。
- 版規查核：讀完 `slashtw.space` tid=2 正文；ADR-0012 加 2026-09-03 修訂、`COMPLIANCE.md` §slashtw 改寫、`README.md` 補 CXC／在水裡寫字與離線閱讀說明。
- `App/Info.plist` build number 同步 `project.yml`（9）。
- Simulator 實測：14 章、單章渲染、底部乾淨。

## 🔄 進行中

- 無

## 🚧 試過但行不通（避免重踩）

- Web-based 單樓隔離（載 thread URL＋CSS 藏其他樓）→ WKWebView 回報的 URL 沒有 `#post` fragment、SPA 懶載入、三個自動化瀏覽器環境全卡 loading，不可靠；改存內文 HTML。
- 用 Claude Browser／Chrome CDP 開 DevTools 查 Waterfall DOM → SPA 不渲染樓層，連已登入的 Chrome 也是；改從 Simulator `default.store` 用 sqlite 唯讀，只印 tag／class 結構。
- `.post-body` selector → fixture 捏造的 class，真站沒有，14 章內文全空。
- Discuz archiver 翻頁（`?page=N`、`-page-N`）→ 都回第 1 頁；版規正文在第 1 樓，已足夠。

## ⚡ 接手要做的事

1. 若 library 還有 2026-09-03 前匯入、沒內文的 slashtw 章節：回該 thread 頁再按一次「匯入」，`applyDocImport` 會以同 URL 合併補上內文。
2. TestFlight 上傳前確認 build number：`project.yml` 與 `App/Info.plist` 都是 9，要先確認上次上傳的號碼。
3. （可選）slashtw／CXC 的 `supportsAutoCheck` 仍為 false；要追更需另開 feature（slashtw 可重用匯入腳本＋`applyDocImport`）。
4. （可選）`SlashTWReaderRuleset.css` 仍是 placeholder，只影響無內文的 fallback 路徑。

## ⚠️ 注意事項

- `xcodegen generate` 會改寫 `App/Info.plist` 的 build number；正本在 `project.yml`，regenerate 後的差異一起 commit，不是來路不明的改動。
- slashtw 的 `contentHTML` 依既有規則不進 iCloud 備份；`LibraryBackupTests.testBackupExcludesContentHTML` 守著。
- 主 checkout 原有的未追蹤舊版 ADR-0012 副本已備份到 session scratchpad，內容是已合併版本的子集，可丟。
- `.claude/worktrees/nice-chatterjee-8696a7` 是另一個 session 的 worktree，本次未動。

## 📁 本次修改的檔案

- `MonoriCore/Sources/MonoriCore/Assets/SlashTWThreadImport.js` — 真實 selector、捲到底載全樓層、`div.content` 內文擷取
- `MonoriCore/Sources/MonoriCore/Assets/SlashTWThreadDetect.js` — 真實 selector
- `MonoriCore/Sources/MonoriCore/HTMLSanitizer.swift` — 新增，stored-HTML importer 共用 sanitizer
- `MonoriCore/Sources/MonoriCore/GoogleDocsChapterSplitter.swift` — `sanitize` 轉呼叫 `HTMLSanitizer`
- `MonoriCore/Sources/MonoriCore/LibraryStore.swift` — doc 再匯入更新標題／作者；CXC URL 比對
- `MonoriCore/Sources/MonoriCore/URLNormalizer.swift` — CXC canonical reader URL
- `MonoriCore/Sources/MonoriCore/Assets/CXCWorkDetect.js`、`CXCWorkImport.js` — 真實 selector
- `App/AppEnvironment.swift` — CXC import-time 標題；slashtw contentHTML sanitize 與「N with stored body」log
- `App/Features/Reader/ReaderView.swift` — slashtw thread URL 保留 reader treatment
- `App/Info.plist` — build number 9
- fixtures 與測試：`slashtw-thread-page*.html`、`cxc-work-page*.html`、`JSExtractionSlashTWTests`、`JSExtractionCXCTests`、`URLNormalizerCXCTests`、`HTMLSanitizerTests`（新）、`LibraryStoreTests`
- `docs/decisions/0012-cxc-slashtw-reading-source-tos.md`、`COMPLIANCE.md`、`README.md`

## 🔗 相關資源

- slashtw 版規：`https://slashtw.space/forum.php?mod=viewthread&tid=2`（純 HTML：`https://slashtw.space/archiver/?tid-2.html`）
- 測試用討論串：`https://waterfall.slashtw.space/thread/96958`（14 樓）
- ADR-0012：`docs/decisions/0012-cxc-slashtw-reading-source-tos.md`
