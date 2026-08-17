# HANDOFF

> 上次 session: 2026-08-17（Google Docs OAuth popup navigationDelegate 修復）
> 下次接手請從「接手要做的事」開始

## 狀態
AsianFanfics 全數修復（2026-08-16 merge）。Google Docs 登入空白畫面：使用者重測發現 Simulator 與另一台實機皆無法重現，僅使用者自己的手機曾出現一次、重啟 app 後正常。已修掉確認的程式碼缺陷（popup 缺 `navigationDelegate`），原症狀判定為裝置特定的 Universal Link association 暫態問題，7-task 計畫擱置。
- 測試/建置狀態：✅ 綠（`./scripts/verify.sh`；`** BUILD SUCCEEDED **`，279 XCTest + 11 swift-testing，0 failures）
- 分支 ＠ 最後 commit：`main @ e9ff55d`（即將 push）
- 工作樹：clean（`brag-output/`、`skills-staging/` 為未追蹤暫存目錄，非本次產物）

## ✅ 本次完成
- `App/WebView/WebViewModel.swift:460`：OAuth popup（`createWebViewWith`）補上 `popup.navigationDelegate = self`，讓 popup 內的導覽也經過 `NavigationPolicy`（含 Universal-Link 抑制）
- 使用者重測 Google 登入結果：(1) 內測成員 iOS 26.5 iPhone 17 無問題 (2) Simulator 無問題 (3) 使用者手機曾出現但重啟後恢復正常。判定為裝置特定暫態，7-task 計畫不執行

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

## 📁 本次修改的檔案
- `App/WebView/WebViewModel.swift` — OAuth popup 補上 `navigationDelegate`

## 🔗 相關資源
- Google 登入計畫：`docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`（未追蹤於 git，擱置）
- ADR-0009：`docs/decisions/0009-asianfanfics-2026-redesign-selectors.md`
