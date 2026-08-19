# HANDOFF

> 最後更新: 2026-08-19（Claude Code 設定移植到 Codex；Uguisu Zen 批次 5 完成）
> 下次接手請從「接手要做的事」開始

## 狀態
Claude Code 的 repo-local 工作流程已移植到 Codex：`CLAUDE.md` 與 `.claude/settings.json` 維持 canonical，Codex 只透過 `AGENTS.md` 與 `.codex/hooks.json` 的 adapter 讀取，不複製 hook command 邏輯。
- 測試/建置狀態：✅ 綠（`./scripts/verify.sh`；290 XCTest + 13 swift-testing，0 failures）
- 分支 ＠ 最後已知狀態：`main` ahead `main/main` 9 commits（本輪未 commit）
- 工作樹：Uguisu Zen 批次 0–5 的未 staged 變更涵蓋規格、`project.yml`／生成的 `App/Info.plist`、語義色資產、字型資源、`MonoriDesignSystem.swift`、App 外殼、書庫／目錄、Browse chrome、設定與閱讀器 chrome。
- 視覺規格：Uguisu Zen 批次 0–5 已完成：字型、色彩 token、Dynamic Type helper、深色映射、Launch Screen／底部導航／WKWebView 背板、書庫／目錄、Browse 的 Monori chrome、設定與閱讀器 chrome；閱讀本文排版仍待分批套用。

## ✅ 本次完成
- 完成 Uguisu Zen 批次 0：加入 Manrope、Source Serif 4、Noto Serif TC 與 OFL 授權檔；在 `project.yml` 註冊 `UIAppFonts`，新增不透明淺／深色語義 token 及 typography／spacing helper；`./scripts/verify.sh` 透過。
- 完成 Uguisu Zen 批次 1：Launch Screen 改為 Washi White＋Sumi Ink；底部導航改用不透明語義色、Manrope 與寬鬆橫向 padding，且綠色僅用於選取圖示；WKWebView 空白背板改為 Monori Canvas。已在模擬器檢查 Browse 與 Settings 的外殼，未互動任何登入或第三方網站流程；`./scripts/verify.sh` 透過。
- 完成 Uguisu Zen 批次 2：書庫、搜尋 sheet 與作品目錄改為 Washi／Stone 的不透明平面結構、Manrope 與 24pt 內容邊距；來源篩選、未讀數與檢查進度移除膠囊／Material，書籤與新章節分別保留 Bookmark Red／Highlight Gold 的語義。修正深色 List cell 回退成系統黑色的問題。模擬器已檢查書庫與目錄的淺／深色，最後還原淺色；`./scripts/verify.sh` 透過。
- 完成 Uguisu Zen 批次 3：Browse 的來源列改為不透明 Canvas／分隔線結構與 Manrope，Web loading 使用 Highlight Gold 線性進度；collection banner 改為 Stone Surface 條帶、Sumi Ink 描邊按鈕與線性進度，移除 Material、prominent 系統按鈕與 spinner。Patreon／其他第三方網站內容未改動。模擬器已檢查 Browse chrome 的淺／深色與來源列展開狀態，最後還原淺色；`./scripts/verify.sh` 透過。
- 完成 Uguisu Zen 批次 4：設定頁改為 Washi Canvas／Stone Surface 的扁平不透明分組、Manrope 與寬鬆間距；主題選項、字級調整與自動檢查改為 8px 圓角矩形控制項。保留外觀、字級、開關、清除資料、登出與診斷匯出行為及 smoke ID；確認與分享仍使用系統原生介面。模擬器已檢查淺／深色，最後還原淺色；`./scripts/verify.sh` 透過。
- 完成 Uguisu Zen 批次 5：閱讀器頂／底 chrome 改為不透明 Canvas、細分隔線與 Manrope；書籤使用 Bookmark Red，章節導覽維持 Sumi Ink。`ReaderPreferencesPanel` 改為可見數值的雙列矩形控制項，並在底部加不透明留白，避免正文與面板交疊；章節切換提示亦移除 Material／Capsule。既有書籤、前後章、離開閱讀器、偏好及 smoke ID 均保留。模擬器已檢查淺／深色，最後還原淺色；`./scripts/verify.sh` 透過。
- 重寫 `DESIGN.md` 為 Uguisu Zen 規格：Manrope UI、Source Serif 4／Noto Serif TC 閱讀器、Washi White／Stone Grey 不透明層次、綠色僅用於導航／品牌，並明確禁止玻璃膠囊。
- 新增 `scripts/codex-hook-adapter.py`：
  - 讀 `.claude/settings.json` 作為 hook source of truth
  - 支援 `PreToolUse`、`SessionStart`、`Stop`、`UserPromptSubmit`、`PreCompact`
  - 將 Codex `functions.exec_command` / `exec_command` payload 正規化為 Claude `Bash`
  - 將 shell source-read（`cat`/`sed`/`nl`/`head`/`tail` 等）轉成 synthetic `Read` payload，讓 Claude `Read|Glob` graphify advisory 也會觸發
  - 自動補 `cwd` 與 `CLAUDE_PROJECT_DIR`
- 更新 `.codex/hooks.json`：
  - 移除使用者家目錄絕對路徑
  - 將 Claude 目前使用的 hook events 全部委派到 adapter
- 更新 `AGENTS.md`：
  - 明確要求 Codex 讀 `CLAUDE.md`、`.claude/hooks/critical_rules.txt`、`SIMULATOR_PLAYBOOK.md`
  - 記錄 `HANDOFF.md`/`MEMORY.md` flow-pack、Claude-local permissions、backup settings、無 `.claude/commands`/`.claude/agents`/repo MCP 設定
- 擴充 `scripts/check-hooks.sh`：
  - 檢查 Claude/Codex hook event parity
  - 禁止 `.codex/hooks.json` 內 `/Users/` 絕對路徑
  - 檢查 adapter 必須 tracked/staged
  - 檢查未來新增 `.claude/commands`、`.claude/agents`、repo MCP config、`.claude/settings.json:mcpServers` 時必須先做 Codex migration decision
  - 檢查 payload regression：非 commit Bash no-op、Codex search graphify advisory、Codex shell source-read graphify advisory、`UserPromptSubmit`/`PreCompact` critical-rules injection

## 🔄 進行中
無。

## 🚧 試過但行不通（避免重踩）
- `graphify update .` 在本輪仍 fail-closed：新 graph 1474 nodes、既有 `graph.json` 1611 nodes，graphify 拒絕覆寫並提示可能缺少前次 session 的 chunk files。不要未經確認用 `--force`。

## ⚡ 接手要做的事
- 下一批為 Uguisu Zen 批次 6：將 ReaderStyler／閱讀本文套用 Source Serif 4／Noto Serif TC、1.8–2.0 行距與 Uguisu Zen 長文欄寬；完成後先截圖驗收。
- 若要 commit，將 Uguisu Zen 批次 0–5 的檔案依設計基礎、外殼／Browse、書庫、設定、閱讀器與交接文件分成原子提交；不要把無關檔案一起掃進去。
- 若未來修改 `.claude/settings.json` hook event，先跑 `./scripts/check-hooks.sh`。新增 Claude hook event 時，Codex 必須新增 `.codex/hooks.json` event registration 或明確記錄不能移植的理由。
- 若要處理 graphify node count mismatch，先查 `graphify-out/` 的 chunk/corpus 狀態，不要直接 `graphify update . --force`。

## ⚠️ 注意事項
- 遠端名稱是 `main` 不是 `origin`（git 會印 `refname 'main' is ambiguous` 警告）。指令中裸寫 `main` 會混淆本地分支與遠端，一律用 `refs/heads/main` 或 `main/main` 明確指定。
- Claude `.claude/settings.local.json` 只是一份 Claude-local allowlist，不是 Codex safety policy；不要把 allow 條目照抄成 repo 規則。
- Codex hook adapter 的設計原則：Codex 只登記 event + 呼叫 adapter；hook command 邏輯留在 `.claude/settings.json`，避免雙份規則漂移。

## 📁 本次修改的檔案
- `AGENTS.md` — Codex adapter / migration inventory / workflow rules
- `.codex/hooks.json` — Codex event registrations
- `scripts/codex-hook-adapter.py` — Claude hook compatibility adapter
- `scripts/check-hooks.sh` — hook parity + payload regression guard
- `HANDOFF.md` — 本輪交接更新
- `MEMORY.md` — 長效決策更新
- `DESIGN.md` — Uguisu Zen 視覺準則
- `App/Features/Shared/MonoriDesignSystem.swift` — Uguisu Zen 語義 token 與 typography helper
- `App/Resources/` — 內嵌字型與 OFL 授權檔
