# HANDOFF

> 上次 session: 2026-08-31
> 下次接手請從「接手要做的事」開始

## 狀態

所有現有功能分支已合併至 `main`；Patreon 匯入排序修復與其測試已完成並通過合併後驗證。

- 已合併：reader navigation/preferences、Codex hook parity、閱歷與 Archive。
- Reader 偏好會跨章與跨故事保留；Chapter TOC 支援左緣右滑返回；閱讀字體與 TOC 共用返回控制。
- 驗證腳本現在一律執行 `xcodegen generate`，避免使用過期的 gitignored `Monori.xcodeproj`。
- Patreon 排序根因：post ID 是建立序號而非收藏順序；collection DOM position 才是匯入 chronology。
- 合併後 `./scripts/verify.sh`：Xcode build 成功，MonoriCore 408/408 tests 通過。
- `docs/decisions/0011-ptt-board-author-collection-source.md` 是既有未追蹤的使用者檔案，未修改。

## ✅ 本次完成

- 閱歷與「已讀完」Archive：status scope chips、日期分組、重開章節、清除確認，以及相應的 Core 測試。
- Reader preferences 移至 `MonoriCore`，以 `UserDefaults` 持久化 font／size／line spacing；URL reader 重新套用現值，stored HTML 路徑維持原行為。
- 新增 `MonoriBackButton`，TOC 與「設定 → 外觀 → 閱讀字體」共用相同 44×44 返回控制與 56pt 頂部列。
- TOC 左緣右滑使用可測試的 24pt 邊界、60pt 距離與水平主導 policy，且保留 chapter row swipe actions。
- Codex hook adapter parity 測試與 fixtures 已合併。
- Patreon refresh 依 collection DOM position 重新編號 incoming 與既有 chapters，partial refresh 保留 scrape window 外章節。

## 🔄 進行中

無。

## 🚧 試過但行不通（避免重踩）

- Patreon numeric post ID 不能當發布時間或故事順序；真實 collection 內會非單調。
- 只改畫面排序 key 不足以修復 refresh：merger 與 `LibraryStore` 必須同步刷新、持久化既有 chapter 的 `orderIndex`。
- 既有 Xcode 專案可能引用已刪除檔案；驗證前必須由 XcodeGen 重新產生。

## ⚡ 接手要做的事

1. 在 Simulator 手動 smoke：閱讀 status scope、閱歷、章節開啟紀錄、TOC 左緣返回，以及 reader preference continuity。
2. 發布後，曾 refresh 過且仍顯示舊順序的收藏，執行一次「檢查新章節」以 collection 位置重寫索引。
3. 於有 iCloud 帳號的裝置測試備份／還原（status + history round-trip），並評估 V2 自動同步與閱歷保留政策。

## ⚠️ 注意事項

- contentHTML 絕不能進 iCloud 備份；SwiftData 必須保持 `cloudKitDatabase: .none`。
- 不新增 `isArchived`；Archive 使用 `readingStatusRaw == "finished"`，且不由 `readingProgress == 1` 自動判定。
- `clearReadingHistory()` 只清閱歷，不動 collections；閱歷 V1 不做自動 TTL 或數量上限。
- 不得以 Patreon post ID 推導 chronology；partial refresh 不得刪除 scrape window 外既有章節。
