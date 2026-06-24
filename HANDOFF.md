# HANDOFF

> 上次 session: 2026-06-24（Chapterly → Monori 全域改名 + merge 回 main）
> 下次接手請從「接手要做的事」開始

## 狀態
全域改名 Chapterly → Monori 完成並 merge 回 `main`（fast-forward）。
- 分支 ＠ 最後 commit：`main @ b2a2ca8`（`rename/monori` 已合併並刪除）
- 測試/建置狀態：✅ 綠（`./scripts/verify.sh` exit 0，build 成功 + 135 tests，0 failures）
- 工作樹：clean

## ✅ 本次完成（2026-06-24）
全域改名 Chapterly → Monori（3 commits）：
- `4aa373c` chore：gitignore `.recall/`
- `8914d4f` refactor：原子改名 — Swift 模組 `MonoriCore`、app target `Monori`、bundle id `dev.monori.Monori`、`@main MonoriApp`、App `Logger(subsystem:)` → `dev.monori`、5 個 scripts
- `b2a2ca8` docs：README / CLAUDE.md / AGENTS.md / COMPLIANCE.md / SIMULATOR_PLAYBOOK.md / config.json / .env.example / hook 文字 + SettingsView UI 字串

最終全分支 review：READY TO MERGE（0 Critical / 0 Important）。計畫全文：`docs/superpowers/plans/2026-06-24-rename-chapterly-to-monori.md`。

## 🔄 進行中
無。

## 🚧 試過但行不通（避免重踩）
- **pre-commit hook 強制原子化**：每個 `git commit` 跑完整 `verify.sh`（要能 build）；半改名的樹 build fail。改名類大重構的 build-affecting 部分必須併成一個 commit。`--no-verify` 是 git flag，擋不掉 Claude Code hook。
- **改名漏抓 Logger subsystem**：Swift `Logger(subsystem: "dev.chapterly")`（App 內 6 處）必須跟 scripts 的 log predicate 一起改成 `dev.monori`，否則 smoke log 收不到。
- **Tier A+B 全改完**：Tier A 大寫 `Chapterly*` + `dev.chapterly`（8914d4f）；Tier B 小寫 `chapterly*` 內部識別碼（本次）。原本靠大小寫區分保留 Tier B，後決定一併改完。
- **CWD drift 導致 hook 失敗**：從子目錄跑 `git commit`，hook 找不到 `./scripts/verify.sh` → commit 前先 `cd` 回 project root。
- **build database disk I/O error**：`.build/build.db` 損壞 → `swift package clean` 修復。

## ⚡ 接手要做的事
1. **使用者手動**（bundle id 已變 `dev.monori.Monori`）：重裝 app → 重登 Patreon → 重 import 一個 collection（SwiftData 容器重置 = 預期，非 bug）。
2. 用真實 Google Doc 重新測試 import（手動 Patreon 登入後跑 `./scripts/smoke-diagnostics.sh`）—— 此項自前次 session 延續，尚未做。

## 🔒 Tier B — 已完成改名（內部跨檔契約）
- 訊息 handler：`monoriImport` / `monoriCollectionLink` / `monoriDrawerDiag` / `monori.backSwipe` / `monori.contentTap`
- CSS 變數：`--monori-font-size` / `--monori-line-height`
- JS 全域 + class：`window.__monori*`、`monori-fade` / `monori-card-style` / `monori-reader-style`

## 📝 刻意留作歷史（仍含舊名 Chapterly）
`MEMORY.md`、`WIKI_SYNC.md`、`docs/monori_rebrand_report.md`、ADR-0001、`docs/superpowers/2026-06-10-*`（plans/specs）—— 含「Chapterly→Monori」轉場標籤或為當日記錄，blanket sed 會打爛。

## ⚠️ 注意事項
- bundle id 變 → 本機資料重置（無遷移碼、無 App Group、SwiftData 用預設容器），需重 import + 重登 Patreon。
- `Monori.xcodeproj` 是 gitignored 產生物：改 `project.yml` 後跑 `xcodegen generate` 重生。

## 🔗 相關資源
- Standard verification：`./scripts/verify.sh`
- Smoke test：`./scripts/smoke-diagnostics.sh`（需手動 Patreon 登入）
- Simulator 操作手冊：`SIMULATOR_PLAYBOOK.md`
