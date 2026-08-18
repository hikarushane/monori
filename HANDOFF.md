# HANDOFF

> 上次 session: 2026-08-18（AO3 auto-check refresher + README/showcase/gitignore 整理）
> 下次接手請從「接手要做的事」開始

## 狀態
AO3 auto-check refresher 完成並合併到 main。所有來源（Patreon、Vocus、AFF、AO3）都支援自動檢查新章節，僅 Google Docs 維持手動（by design）。README 加入 showcase 截圖區塊，App Review Guide 更新登入說明。
- 測試/建置狀態：✅ 綠（`./scripts/verify.sh`；285 XCTest + 13 swift-testing，0 failures）
- 分支 ＠ 最後 commit：`main @ 6d9395c`
- 工作樹：clean

## ✅ 本次完成
- AO3 auto-check refresher（worktree SDD，3 commits merged fast-forward）：
  - `applyDocImport` nil contentHTML 保護（不再用 nil 覆寫已存的離線內容）
  - `runAO3RefresherImport`：透過 navigate page 偵測新章節，只抓新章節內容（1s 間隔），呼叫 `applyDocImport` 合併
  - `SourceKind.supportsAutoCheck` 對 `.ao3` 回傳 `true`；`CollectionRefreshOutcome.unsupported` doc comment 更新
  - On-device 驗證：「紙上幽靈」5→6 章，unread badge 正常，log 無錯誤
- Vocus/AFF auto-check 啟用（先前 session 開始，本次 push）
- README 加入 `docs/showcase/` 截圖區塊，使用方式段落對應截圖編號
- DESIGN.md 更新至 Uguisu Zen 色彩系統，移除舊品牌草稿
- `.gitignore` 整理（`build/`、`.build/` 加回）
- App Review Guide 更新：明確說明 Patreon 和 Google Docs 共用同一組 Google 帳號登入

## 🔄 進行中
無

## 🚧 試過但行不通（避免重踩）
無新增

## ⚡ 接手要做的事
無特定待辦。若 Google 登入空白畫面再次出現，原 7-task 計畫仍可參考：`docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`（未追蹤於 git）

## ⚠️ 注意事項
- 遠端名稱是 `main` 不是 `origin`（git 會印 `refname 'main' is ambiguous` 警告）。指令中裸寫 `main` 會混淆本地分支與遠端，一律用 `refs/heads/main` 或 `main/main` 明確指定
- **計畫檔案不在 git 版控裡**：`docs/superpowers/plans/` 因 `.gitignore` 被排除，只存在本機工作目錄
- AFF 選擇器改動前務必先對正式站即時 DOM 重新驗證
- AO3 refresher 設計：navigate page diff + 只抓新章節 + 1s rate-limit delay；單章作品若無 navigate entries 會回 `.failed`（無資料遺失，awareness only）

## 📁 本次修改的檔案
- `App/AppEnvironment.swift` — `runAO3RefresherImport` + `.ao3` case + doc comment fix
- `MonoriCore/Sources/MonoriCore/LibraryStore.swift` — `applyDocImport` nil contentHTML 保護
- `MonoriCore/Sources/MonoriCore/SourceKind.swift` — `.ao3` supportsAutoCheck = true
- `MonoriCore/Tests/MonoriCoreTests/LibraryStoreTests.swift` — contentHTML preservation test
- `README.md` — 截圖區塊 + 使用方式更新 + auto-check 描述更新
- `DESIGN.md` — Uguisu Zen 色彩系統
- `.gitignore` — 規則整理
- `docs/app-review/APP_REVIEW_GUIDE.md` — 登入說明更新
- `docs/showcase/` — 新增行銷素材（截圖 + 模板 + 文案）
- `docs/app-review/` — 新增 App Store 審核指南

## 🔗 相關資源
- Google 登入計畫：`docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`（未追蹤於 git，擱置）
- ADR-0009：`docs/decisions/0009-asianfanfics-2026-redesign-selectors.md`
- AO3 refresher 計畫：`docs/superpowers/plans/2026-08-18-ao3-auto-check-refresher.md`（未追蹤於 git）
