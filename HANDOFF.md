# HANDOFF

> 上次 session: 2026-06-22（regex 靜態化重構 + largeFontTitle 測試補充）
> 下次接手請從「接手要做的事」開始

## 狀態
Google Docs import 的 regex 效能重構完成，新測試通過。所有功能性 commit 在 `main`；重構+測試未 commit。
- 測試/建置狀態：✅ 綠（`cd ChapterlyCore && swift test --filter GoogleDocsChapterSplitterTests` 18/18）
- 分支 ＠ 最後 commit：`main @ dcc1f76`
- 工作樹：dirty — `GoogleDocsChapterSplitter.swift`（regex 靜態化）+ `GoogleDocsChapterSplitterTests.swift`（新測試）

## ✅ 本次完成（2026-06-22）
- **regex 靜態化重構**：`largeFontTitle` 的 font-size regex 和 `chapterMarkerCount` 的 marker regex 從每次呼叫 `try?` 編譯改為 `static let fontSizeRegex` / `static let chapterMarkerRegex` 快取（效能優化，功能不變）
- **`testLargeFontNonTitleTextAcceptedAsChapter`**：驗證大字體非章回格式文字（「重要提醒」「寫在最後」）被 `largeFontTitle` 接受為章節邊界（設計意圖確認測試）

## 🔄 進行中
無。改動完成但未 commit。

## 🚧 試過但行不通（避免重踩）
- **CWD drift 導致 hook 失敗**：從 `ChapterlyCore/` 子目錄跑 `git commit`，pre-commit hook 找不到 `./scripts/verify.sh` → commit 前先 `cd` 回 project root
- **build database disk I/O error**：`.build/build.db` 損壞 → `swift package clean` 修復

## ⚡ 接手要做的事
1. commit 工作樹中的 2 個改動（`GoogleDocsChapterSplitter.swift` + tests）
2. 用真實 Google Doc 重新測試 import（手動 Patreon 登入後跑 `./scripts/smoke-diagnostics.sh`）
3. 全域改名 Chapterly → Monori（見 MEMORY.md 詳細清單）

### 全域改名 Chapterly → Monori（延續）

**先決：開新分支**（建議 `rename/monori`）。改 bundle id 會讓 Patreon 登入失效 + 本機書庫資料重置，必須隔離成獨立 PR。

**重點：不要整包 `s/Chapterly/Monori/`**，會打爛 JS↔Swift / CSS 跨檔契約。

#### Tier A — 要改（使用者可見身分 + Swift 模組）
1. `project.yml`：name/bundleIdPrefix/package/target
2. 目錄 `git mv`：`ChapterlyCore/` → `MonoriCore/`（含子目錄）
3. `Package.swift`：name/products/targets
4. Swift source：`import ChapterlyCore` → `MonoriCore`；`ChapterlyApp` → `MonoriApp`
5. scripts：`.xcodeproj`/`-scheme`/bundle id/log predicate/DerivedData glob
6. 文件：README/CLAUDE.md/AGENTS.md 等

#### Tier B — 不要改（內部識別碼，跨檔契約）
- 訊息 handler：`chapterlyImport`/`chapterlyCollectionLink`
- CSS 變數：`--chapterly-font-size`/`--chapterly-line-height`
- JS 全域：`window.__chapterly*`、`chapterly-fade`/`chapterly-card-style`/`chapterly-reader-style`

#### 驗證順序
1. `xcodegen generate` → `xcodebuild -list -project Monori.xcodeproj`
2. `./scripts/verify.sh`
3. 使用者手動：重裝 app → 重登 Patreon → 重新 import collection

## ⚠️ 注意事項
- 工作樹有 2 檔未 commit（regex 重構 + 測試，不影響功能）
- bundle id 一變 → 本機資料重置（無遷移碼），需重 import + 重登 Patreon

## 📁 本次修改的檔案
- `ChapterlyCore/Sources/ChapterlyCore/GoogleDocsChapterSplitter.swift` — `fontSizeRegex` + `chapterMarkerRegex` 提取為 static let
- `ChapterlyCore/Tests/ChapterlyCoreTests/GoogleDocsChapterSplitterTests.swift` — 新增 `testLargeFontNonTitleTextAcceptedAsChapter`

## 🔗 相關資源
- Standard verification：`./scripts/verify.sh`
- Smoke test：`./scripts/smoke-diagnostics.sh`（需手動 Patreon 登入）
- Simulator 操作手冊：`SIMULATOR_PLAYBOOK.md`
