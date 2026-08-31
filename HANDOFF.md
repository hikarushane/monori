# HANDOFF

> 上次 session: 2026-08-25
> 下次接手請從「接手要做的事」開始

## 狀態
閱歷＋Archive（已讀完）功能實作完成。
- 測試/建置狀態：✅ `swift test --package-path MonoriCore`（399+ tests, 0 failures）；✅ Xcode build exit 0
- 分支：`worktree-reading-history-archive`（基於 main）

## ✅ 本次完成
- `.finished` label 從「已完結」改成「已讀完」；raw value 保持 `finished`
- `setReadingStatus(.finished)` 原子性清除所有 `isNew`，不動 bookmark/progress/history/lastReadAt
- `clearReadingHistory()` 只清 history，不動 collections
- `chapter(id:)` 以 stable ID resolve chapter（供閱歷 row tap）
- `ReadingHistoryQuery` 日期分組（injectable calendar/timezone，7 tests 含 DST 邊界）
- `syncCurrentChapter` SPA library-chapter transition 補上 `recordChapterOpened`
- Library status scope chips（追更中/已讀完/棄坑），預設追更中
- 篩選後 count + 每個 scope 獨立空狀態
- 搜尋 sheet 尊重 status + source filter
- `ReadingHistoryView`：日期分組、row tap 重開、已移除章節顯示、清除確認
- Library header 閱歷按鈕（clock.arrow.circlepath）
- PreviewSupport 擴充 history/status-varied 環境 + 7 新 previews
- APP_REVIEW_GUIDE.md 加入 status scope 和閱歷說明
- 新增 10+ 測試（archive status, clearReadingHistory, chapter(id:), history query）

## 🔄 進行中
無。

## 🚧 試過但行不通（避免重踩）
- SPM `build.db` corruption：新增 test 檔案後 XCTest runner 找不到新 test，需刪除 `MonoriCore/.build/build.db` 重建
- `ModelConfiguration.CloudKitDatabase` 不支援 `Equatable`，migration test 用 `String(describing:)` + `contains("_none: true")` 繞過
- XcodeGen 會覆寫 entitlements：必須在 `project.yml` 的 `entitlements:` 下用 `properties:` 宣告內容，否則 `xcodegen generate` 產生空 `<dict/>`

## ⚡ 接手要做的事
1. merge 回 main，跑 `./scripts/verify.sh` 確認全綠
2. 在 Simulator 上跑一次 smoke test，確認 status scope、閱歷 UI、章節開啟紀錄正常
3. 確認手動 Patreon 登入後備份/還原流程（status + history round-trip）
4. 考慮是否需要 V2 自動同步或閱歷保留政策

## ⚠️ 注意事項
- contentHTML 絕不能進 iCloud 備份
- SwiftData 必須保持 `cloudKitDatabase: .none`（有 migration test 鎖住）
- 不新增 `isArchived`；Archive 直接使用 `readingStatusRaw == "finished"`
- 不自動用 `readingProgress == 1` 判定已讀完
- 閱歷 V1 不做自動 TTL 或數量上限
- 清除閱歷不自動覆寫 iCloud backup

## 📁 本次新增/修改的檔案
### 新增
- `MonoriCore/Sources/MonoriCore/ReadingHistoryQuery.swift` — 日期分組 helper
- `MonoriCore/Tests/MonoriCoreTests/ReadingHistoryQueryTests.swift` — 7 grouping tests
- `App/Features/Library/ReadingHistoryView.swift` — 閱歷畫面 + previews

### 修改
- `App/Features/Library/CollectionReadingStatus+Label.swift` — `.finished` → 「已讀完」
- `MonoriCore/Sources/MonoriCore/LibraryStore.swift` — `clearReadingHistory()`, `chapter(id:)`, finished 清 isNew
- `MonoriCore/Tests/MonoriCoreTests/LibraryStoreTests.swift` — archive status + clearHistory + chapter(id:) tests
- `MonoriCore/Tests/MonoriCoreTests/LibraryQueryTests.swift` — status filter tests
- `App/Features/Library/LibraryView.swift` — status scope chips, history button, scoped empty states, search filter
- `App/Features/Reader/ReaderView.swift` — SPA transition recordChapterOpened
- `App/Preview/PreviewSupport.swift` — history + status-varied environments
- `docs/app-review/APP_REVIEW_GUIDE.md` — status scope + reading history docs
- `HANDOFF.md` — 本文件

## 🔗 相關資源
- Brief：`docs/superpowers/plans/2026-08-25-Reading-History-Archive-Implementation-Brief.md`
- iCloud backup DTO 已包含 `readingStatusRaw` 和 `ReadingHistoryBackup`，不需額外 schema 變更
