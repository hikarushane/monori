# HANDOFF

> 上次 session: 2026-08-19（Claude Code 設定移植到 Codex）
> 下次接手請從「接手要做的事」開始

## 狀態
Claude Code 的 repo-local 工作流程已移植到 Codex：`CLAUDE.md` 與 `.claude/settings.json` 維持 canonical，Codex 只透過 `AGENTS.md` 與 `.codex/hooks.json` 的 adapter 讀取，不複製 hook command 邏輯。
- 測試/建置狀態：✅ 綠（`./scripts/verify.sh`；290 XCTest + 13 swift-testing，0 failures）
- 分支 ＠ 最後已知狀態：`main` ahead `main/main` 1 commit（本輪未 commit）
- 工作樹：migration 檔案已 staged；`docs/showcase/2.png` 是既有未 staged 變更，非本輪修改

## ✅ 本次完成
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
- `graphify update .` 在本輪仍 fail-closed：新 graph 1422 nodes、既有 `graph.json` 1608 nodes，graphify 拒絕覆寫並提示可能缺少前次 session 的 chunk files。不要未經確認用 `--force`。

## ⚡ 接手要做的事
- 若要 commit，本輪 staged 檔案可作為 migration commit 候選；不要把既有的 `docs/showcase/2.png` 一起掃進去。
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
