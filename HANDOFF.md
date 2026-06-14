# HANDOFF

> 上次 session: 2026-06-14（R5 reader dismiss 重校準）
> 下次接手請從「接手要做的事」開始

## 狀態
MVP branch `feat/mvp-implementation`。`smoke.readerDismissButton` 已完成並提交（`e2c0181`）且 R5 playbook 已重校準（2026-06-14）：Driver B tap (26, 84) PASS；Driver A `computer_batch` body (1013,563) → dismiss (878,180) PASS。`SIMULATOR_PLAYBOOK.md` 已更新 R5 gesture 表和 verified log。

## ✅ 本次完成
- **Reader Debug-only dismiss button**：
  - `App/Features/Reader/ReaderView.swift`：在 `topBar` `HStack` 第一個 child 加 `#if DEBUG` button。
  - button 使用 `Image(systemName: "chevron.left")`、44×44 tap target、`.buttonStyle(.plain)`、`.accessibilityLabel("Close reader")`、`.accessibilityIdentifier("smoke.readerDismissButton")`。
  - action 直接 `dismiss()`；不走 `handleBackSwipe()` / webview `goBack()`，目標是保證退出 `.fullScreenCover` reader。
  - button 在 `topBar` 裡，所以仍只在 `chromeVisible == true` 時出現；Release build 編譯排除。
- **Smoke identifier docs sync**：
  - `CLAUDE.md` 和 `AGENTS.md` 的 Useful identifiers list 都加入 `smoke.readerDismissButton`，位置在 `smoke.readerPrefsButton` 與 `smoke.refreshChaptersButton` 之間。
- **驗證與 review**：
  - Task-level spec review：通過。
  - Task-level code quality review：通過；唯一提醒是 Debug-only 多一個 leading 44pt control 會讓 title 空間少 44pt，非 blocker，符合規格。
  - `xcodegen generate`：exit 0；`Chapterly.xcodeproj` 無 diff。
  - `xcodebuild -list -project Chapterly.xcodeproj`：exit 0；`Chapterly` target/scheme 存在。
  - `./scripts/verify.sh`：commit 前與 commit 後皆 exit 0；Debug build succeeded；ChapterlyCore 84 tests, 0 failures。
  - Final committed-diff review：No issues found。
- **Commit**：
  - `e2c0181 feat(reader): add Debug-only dismiss button to reader top bar`
- **Task 3 視覺檢查結果**：
  - booted Simulator：`iPhone 17 Pro (iOS 26.5)`。
  - `ui-preflight.sh` / `ui-driver.sh doctor`：OK。
  - 目前 app 狀態不是 ReaderView；`describe` 沒有 `smoke.reader*` identifiers。
  - 嘗試從章節列表進 reader 時進到 Patreon web content，不是 Debug ReaderView；未繼續點 Patreon 頁面，避免撞 login / human verification。
- **Driver A（computer-use MCP）手勢校準**（桌面版 Claude Code session）：
  - 流程：`ui-preflight` + `ui-driver.sh doctor`（B 也 ready 作備援）→ ToolSearch `computer-use` → `request_access ["Simulator"]` → `open_application` → screenshot 定位
  - **R1 tap control = PASS**：`left_click` 控制中心（tab bar Library ≈(304,763)、toolbar sort ≈(385,187)）
  - **R2 tap list row = PASS**：`left_click` 列標題文字 x≈210（≈20–30% 內容寬）
  - **R3 back edge-swipe（NavigationStack）= PASS（須連續拖曳）**：`mouse_move`→`left_mouse_down`→6× `mouse_move` 步進→`left_mouse_up`（155→420 @ y458）。**Driver A 在這裡成功，Driver B 的 idb swipe 失敗**（B 須 tap `<`）
  - **R4 reader chrome toggle = PASS**：`left_click` 內容中心 (304,458)，雙向切換
  - **R5 reader dismiss = PASS（2026-06-14 重校準）**：`smoke.readerDismissButton` tap。Driver A: `computer_batch` body (1013,563) → wait 0.8s → dismiss (878,180)；calibration content_left≈858 top≈115 scale≈0.769×0.773。原 edge-drag FAIL 紀錄不變；relaunch 仍為 fallback。
  - **R6 scroll = PASS（用 drag；wheel 失敗）**：`scroll` 工具（滑鼠滾輪）amount 5/15 在 WKWebView 完全不動；改 `left_click_drag` (304,620)→(304,230) 上滑捲動 ~1 屏
- 更新 `SIMULATOR_PLAYBOOK.md` verified log：Driver A 欄六列 pending → 實際結果；zero-touch 彩排註記更新
- 校準截圖：`build/smoke/ui/a-step01..07*.png`
- 校準中觸發一次 Cloudflare 人類驗證（首次開章載入 `www.patreon.com`）→ 依 handoff 協定停手、使用者手動清除後續跑

## 🔄 進行中
- **AGENTS.md drift**：identifier list 的 `smoke.readerDismissButton` 已更新；若還有 progress/bookmark 措辭舊、無 smoke-auto 段落等 broader drift，需另案處理。
- **Manual UX sweep**（延續）：reader prefs panel / Browse animation / refresh banner 仍需人工在模擬器確認

## ⚡ 接手要做的事
1. **Manual UX sweep**：模擬器確認 reader prefs / Browse animation / refresh banner
2. **PR 準備**：整理 branch，推送，開 PR

## ⚠️ 注意事項
- **Patreon 登入必須保留**：不要 erase/reset/uninstall 模擬器
- `smoke.readerDismissButton` 只在 Debug build 存在，且只在 reader chrome 顯示時出現；先 body tap 顯示 chrome 再 tap dismiss。
- **R5 Driver B recipe**：body tap y≈650 顯示 chrome → `describe` 取 frame → tap center (26, 84)。
- **R5 Driver A recipe**：`computer_batch` body (1013,563) → wait 0.8s → dismiss (878,180)；calibration content_left≈858 top≈115 scale≈0.769×0.773。Relaunch 仍為 fallback。
- **Driver A R6**：滑鼠滾輪 `scroll` 工具對 WKWebView reader 無效，必須用 `left_click_drag` 模擬觸控拖曳
- **Driver A R3 須連續拖曳**：單次 `left_click_drag` 太快可能不觸發 `interactivePopGesture`；用 `left_mouse_down` + 多次 `mouse_move` + `left_mouse_up`
- **Driver A 首次開章可能撞 Cloudflare**：載入 patreon.com 時的人類驗證屬預期人工步驟，撞到立即停手等使用者
- `back)` 在 Reader 畫面禁用：(20,79) 是書籤按鈕不是返回（Driver B）
- `smoke-auto.sh` 會 `source .env`；有嚴禁讀 `.env` 約束時不可直接跑
- Driver A 校準必須在桌面版 Claude Code；CLI / web / Codex 無 computer-use MCP

## 📁 本次修改的檔案
- `App/Features/Reader/ReaderView.swift` — Debug-only `smoke.readerDismissButton`（commit `e2c0181`）
- `CLAUDE.md` / `AGENTS.md` — smoke identifier list 加 `smoke.readerDismissButton`（commit `e2c0181`）
- `SIMULATOR_PLAYBOOK.md` — R5 gesture 表 + verified log B/A 從 FAIL→PASS（2026-06-14 重校準）；Driver A 六列實測結果；zero-touch 彩排 + R5 recalibration 更新
- `HANDOFF.md` / `MEMORY.md` — 本次 session 更新

## 🔗 相關資源
- Reader dismiss button 計畫：`docs/superpowers/plans/2026-06-13-reader-dismiss-button.md`
- Simulator 操作手冊：`SIMULATOR_PLAYBOOK.md`
- Simulator automation 計畫：`docs/superpowers/plans/2026-06-13-computer-use-simulator-automation.md`
- UX 修復計畫（前次）：`docs/superpowers/plans/2026-06-13-ux-sweep-fixes-browse-nav.md`
- Standard verification：`./scripts/verify.sh`
- Semi-manual diagnostics：`./scripts/smoke-diagnostics.sh`
- Smoke auto（注意會讀 `.env`）：`./scripts/smoke-auto.sh`
