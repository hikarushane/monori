# HANDOFF

> 上次 session: 2026-08-25
> 下次接手請從「接手要做的事」開始

## 狀態
iCloud 備份＋閱歷功能實作完成，6 個 commit 已全部建立並通過 pre-commit hook (verify.sh)。
- 測試/建置狀態：✅ `swift test --package-path MonoriCore`（367/367 tests, 0 failures）；✅ Xcode build exit 0
- 分支＠最後 commit：`main`

## ✅ 本次完成
- **Commit 1** (`bb12521`): `LocalReadingHistoryEntry` SwiftData model + 5 分鐘 coalescing + `recordChapterOpened()` 取代 `markChapterOpened()` + 單一 chapter-open write point (CollectionTOCView → ReaderView.open) + 6 tests
- **Commit 2** (`cb8f02f`): `LibraryBackupEnvelope` Codable DTO + `makeBackupSnapshot()` / `restoreBackupSnapshot()` + fail-closed validation + rollback on failure + contentHTML 排除 + 12 tests
- **Commit 3** (`989bc5f`): `ModelConfiguration(cloudKitDatabase: .none)` 明確 local-only + migration test
- **Commit 4** (`f3ee812`): `CloudBackupTransport` protocol + `CloudKitBackupTransport` + `ICloudBackupService` + `Monori.entitlements` (iCloud/CloudKit) + `InMemoryBackupTransport` fake + 9 tests
- **Commit 5** (`f62d4ed`): Settings UI「iCloud 備份」section（metadata 顯示、立即備份、從 iCloud 還原、force overwrite、iCloud 不可用狀態、ProgressView）+ 清除書庫確認文字更新 + 關於隱私文字更新
- **Commit 6**: `COMPLIANCE.md` iCloud 備份段落 + `HANDOFF.md` 更新（本 commit）

## 🔄 進行中
無。

## 🚧 試過但行不通（避免重踩）
- SPM `build.db` corruption：新增 test 檔案後 XCTest runner 找不到新 test，需刪除 `MonoriCore/.build/build.db` 重建
- `ModelConfiguration.CloudKitDatabase` 不支援 `Equatable`，migration test 用 `String(describing:)` + `contains("_none: true")` 繞過
- XcodeGen 會覆寫 entitlements：必須在 `project.yml` 的 `entitlements:` 下用 `properties:` 宣告內容，否則 `xcodegen generate` 產生空 `<dict/>`

## ⚡ 接手要做的事
1. 在實機或 Simulator 上跑一次完整 smoke test（手動 Patreon 登入後 `./scripts/smoke-auto.sh`），確認備份/還原 UI 正常運作
2. 在有 iCloud 帳號的裝置上測試實際備份與還原流程
3. 考慮是否需要 V2 自動同步功能

## ⚠️ 注意事項
- contentHTML 絕不能進 iCloud 備份（`ChapterBackup` DTO 刻意沒有 `contentHTML` field，這是 release blocker）
- SwiftData 必須保持 `cloudKitDatabase: .none`（有 migration test 鎖住）
- restore 失敗會 rollback 到操作前的 local snapshot，不會毀掉使用者現有書庫
- iCloud 備份 V1 只有手動備份/還原，沒有自動同步

## 📁 本次新增/修改的檔案
### 新增
- `MonoriCore/Sources/MonoriCore/LibraryBackup.swift` — backup DTO + export/restore logic
- `MonoriCore/Sources/MonoriCore/CloudBackupTransport.swift` — transport protocol + error types
- `MonoriCore/Tests/MonoriCoreTests/LibraryBackupTests.swift` — 12 backup tests
- `MonoriCore/Tests/MonoriCoreTests/CloudBackupTransportTests.swift` — 9 transport tests + InMemoryBackupTransport fake
- `App/Services/ICloudBackupService.swift` — backup service with state machine
- `App/Services/CloudKitBackupTransport.swift` — CloudKit implementation
- `App/Monori.entitlements` — iCloud/CloudKit entitlements (由 xcodegen 從 project.yml 生成)

### 修改
- `MonoriCore/Sources/MonoriCore/Models.swift` — 新增 `LocalReadingHistoryEntry`
- `MonoriCore/Sources/MonoriCore/LibraryStore.swift` — `recordChapterOpened()` + history coalescing + `readingHistory()` queries + `clearLibrary()` 清閱歷
- `MonoriCore/Tests/MonoriCoreTests/LibraryStoreTests.swift` — 6 history tests + container update
- `MonoriCore/Tests/MonoriCoreTests/ModelMigrationTests.swift` — local-only assertion test
- `App/AppEnvironment.swift` — lazy `backupService` property
- `App/Features/Settings/SettingsView.swift` — iCloud 備份 section + 清除書庫/關於文字更新
- `App/Features/Library/CollectionTOCView.swift` — 移除 duplicate `markChapterOpened()` call
- `App/Features/Reader/ReaderView.swift` — `recordChapterOpened()` 替換
- `project.yml` — entitlements properties
- `COMPLIANCE.md` — iCloud 備份段落 + 資料刪除/工程紅線更新
- `HANDOFF.md` — 本文件

## 🔗 相關資源
- Brief 原文在 2026-08-25 session context 的第一則 user message（28 sections）
- `InMemoryBackupTransport` fake 可用於 app-level integration test
