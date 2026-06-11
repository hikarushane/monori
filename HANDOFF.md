# HANDOFF

> 上次 session: 2026-06-11
> 下次接手請從「接手要做的事」開始

## 狀態
MVP bug fix rounds 1–4 全部完成並 committed；等待 Simulator 手動驗證。

## ✅ 本次完成
- **Reader 自動滑到底部** → `enforceScrollScript` 4s/400ms interval 強制回 target；`ProgressTracker.js` 加 user-interaction gate（`touchstart`/`wheel` 才存 progress）
- **章節標題顯示內文** → `ChapterTextFormatter.looksLikeBodyText()` 縮減至只檢查 `。`；`presentation()` 加 `firstLineIsTitle` 判斷，fallback URL slug
- **Prev/Next 按鈕反向** → `neighbors()` 改用 descending `orderIndex`（Patreon DOM 最新 = orderIndex 0 = 故事順序最舊）
- **Library 無 teaser 文字** → `excerptFromCard()` 三層搜尋：anchor 內 → anchor 文字行 → 向上爬最多 4 層父節點（多 post 容器前停止）；`excerpt` 欄位貫穿 Payloads → Models → ChapterMapMerger → LibraryStore → CollectionTOCView
- **"From the collection" 導航後 banner/title 不更新** → `ReaderView.swift` 加 `.onChange(of: env.reader.currentURL)` → `syncCurrentChapter(to:)`
- 全部 unit tests pass（`2026-06-11 16:33:25.882`）
- 新增 fixtures 及對應測試（sibling teaser、enforceScroll、excerpt merge）
- Committed: `fix(reader,library): fix scroll position, teaser extraction, SPA navigation sync`

## ⚡ 接手要做的事
1. 在 iOS Simulator 重新 import collection（例：patreon.com/collection/2040508）→ 驗證 Library TOC 出現 teaser 文字
2. 開啟文章，確認從頂部或已存 progress 開始，不滑到底
3. 點 "From the collection" 連結，確認 banner 和底部標題更新
4. （可選）跑 `./scripts/verify.sh` 確認 build + unit tests 仍過

## ⚠️ 注意事項
- 舊 progress 若被 Patreon auto-scroll 污染（值接近 1.0），第一次開文章可能仍跳到接近底部 — 手動滾一下即覆蓋
- Re-import 必要：現有 chapter 的 `excerpt` 欄位是 nil，需重新 import 才填入 teaser
- `smoke-auto.sh` 尚未驗證此批改動

## 📁 本次修改的檔案
- `App/Features/Reader/ReaderView.swift` — 加 SPA navigation sync（`syncCurrentChapter`）、`applyReaderTreatment` 改用 `enforceScrollScript`
- `App/Features/Library/CollectionTOCView.swift` — 顯示 `chapter.excerpt`，移除展開/收合按鈕
- `ChapterlyCore/Sources/ChapterlyCore/Assets/CollectionImport.js` — 新增 `excerptFromCard()` 三層 DOM 搜尋
- `ChapterlyCore/Sources/ChapterlyCore/Assets/ProgressTracker.js` — 加 user-interaction gate
- `ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift` — 新增 `enforceScrollScript(progress:)`
- `ChapterlyCore/Sources/ChapterlyCore/ChapterTextFormatter.swift` — `looksLikeBodyText()` 縮減
- `ChapterlyCore/Sources/ChapterlyCore/Models.swift` — `LocalChapterModel.excerpt: String?`
- `ChapterlyCore/Sources/ChapterlyCore/Payloads.swift` — `ImporterChapterPayload.excerpt: String?`
- `ChapterlyCore/Sources/ChapterlyCore/PayloadValidator.swift` — `"excerpt"` 加入 optional fields
- `ChapterlyCore/Sources/ChapterlyCore/ChapterMapMerger.swift` — excerpt merge 邏輯
- `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift` — `applyImport` 傳遞 excerpt；`neighbors()` descending orderIndex
- Tests: `ChapterMapMergerTests`, `ChapterTextFormatterTests`, `JSExtractionTests`, `LibraryStoreTests`, `ReaderStylerTests`

## 🔗 相關資源
- `scripts/verify.sh` — automated build + unit tests
- `scripts/smoke-diagnostics.sh` — manual smoke test with Patreon login
- `scripts/smoke-auto.sh` — full smoke loop (需先 Simulator 手動登入 Patreon)
