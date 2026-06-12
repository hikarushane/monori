# HANDOFF

> 上次 session: 2026-06-12/13（session 4）
> 下次接手請從「接手要做的事」開始

## 狀態
Library & Reader UX Overhaul（Tasks 1–9）全部提交完成。使用者手動 UX sweep 發現 5 個問題；
已系統化調查（凍結根因實驗確認）、修復計畫已寫好但**未實作**：
`docs/superpowers/plans/2026-06-13-ux-sweep-fixes-browse-nav.md`（7 個 task）。

## ✅ 本次完成
- T5 reader overhaul 提交（`b4b8a99`，含 SettingsView 一行編譯修正）
- T6 一鍵檢查新章節提交（`c5d7c66`）：`env.refresher` 離屏 WebViewModel + TOC ↻ 按鈕取代手動新增
- T7 移除閱讀進度功能提交（`aafa02c`）：smoke loop 改 8 步、`grep` 零殘留 progress 引用
- T9 文件提交（`c10dd62`）：README/CLAUDE.md 改書籤敘述；`.gitignore` 加 `docs/`、`*.log`、`WIKI_SYNC.md`
- `4e6e8c1`：untrack `build/smoke/*.log`（gitignore 不影響已追蹤檔，補 `git rm --cached`）
- UX sweep 調查完畢：
  - **凍結根因確認**：`@Observable` + didSet 自我賦值 = 無限遞迴（/tmp scratch test 證實；plain class 安全、@Observable 不安全）
  - NavigationPolicy 排除嫌疑（全 patreon.com URL 都 allow）
  - CollectionImport.js 只點 button 不點 anchor（H2 洗版假說仍開放）
- 新修復計畫寫好（見「狀態」路徑）

## 🔄 進行中
- **UX sweep 修復計畫**：0/7 task。Task 1 = P0 凍結修復（完整程式碼在計畫內）；
  Task 5 = 三分支決策題（A=H1 / B=H2 / C=H3），必須先跑 Task 2 診斷 + 使用者重現後依判讀表選一個分支
- **smoke-auto.sh（8 步版）從未實跑**：併入新計畫 Task 6 step 2

## ⚡ 接手要做的事
1. 讀計畫 → 用 superpowers:executing-plans（或 subagent-driven-development）執行 Task 1（P0 凍結修復）→ `./scripts/verify.sh` → 提交
2. Task 2：加 back-swipe 診斷 log → 提交 → **停下來請使用者重現 #5/#6 並跑 `./scripts/smoke-diagnostics.sh`** → `grep back_swipe build/smoke/app.log` → 依計畫 Task 2 step 5 判讀表記錄裁決
3. Task 3（snapshot 滑出動畫 + 進度條）、Task 4（refresh 狀態橫幅）獨立可先做
4. Task 5 依裁決只實作一個分支；Task 6 驗證（需使用者）；Task 7 文件提案（需使用者確認）

## ⚠️ 注意事項
- working tree 乾淨（HANDOFF/MEMORY 本檔更新除外）；verify.sh 通過（build + core 84/84）
- **Patreon 登入必須保留**：嚴禁 erase/重置模擬器、嚴禁讀 `.env`、嚴禁 log cookie/token（URL path 可以）
- 不要 `git add -A`（docs/、*.log、WIKI_SYNC.md 已 gitignore，但列明檔案是鐵則）
- 計畫 Task 7 之外不可動 README.md / CLAUDE.md（全域規則：先提案、使用者確認才編輯）
- Refresh「成功匯入」結果待 Patreon 真的出新章節才能驗證（計畫 Task 6 step 3 第 5 點）

## 📁 本次修改的檔案
- `App/Features/Reader/{ReaderPreferences,ReaderPreferencesPanel,ReaderView}.swift` — T5 沉浸式 reader（b4b8a99）
- `App/Features/Settings/SettingsView.swift` — T5 移除 toggle；T7 文案改 bookmarks
- `App/AppEnvironment.swift`、`App/Features/Library/CollectionTOCView.swift`、`App/Features/Shared/WebCollectionBanner.swift`、`ChapterlyCore/.../LibraryStore.swift` — T6 refresh 流程
- T7 全面移除 progress：`Payloads/PayloadValidator/ScriptMessageRouter/JSAssets/Models/ReaderStyler.swift` + 4 個測試檔 + `App/WebView/WebViewModel.swift` + `App/SmokeAutopilot.swift` + `scripts/smoke-auto.sh`（EXPECTED_STEPS=8）；刪 `ReaderProgressPolicy.swift`、`ProgressTracker.js`
- `README.md`、`CLAUDE.md`、`.gitignore` — T9（c10dd62）

## 🔗 相關資源
- 修復計畫：`docs/superpowers/plans/2026-06-13-ux-sweep-fixes-browse-nav.md`（含 verified facts、三假說判讀表、Appendix A webview-stack 暫緩方案）
- 上輪 overhaul 計畫：`docs/superpowers/plans/2026-06-12-library-reader-ux-overhaul.md`（已全部執行完）
- UX sweep 原始回報（2026-06-12，使用者）：9 項，見計畫 Background 表
