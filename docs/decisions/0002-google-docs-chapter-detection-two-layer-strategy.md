# ADR-0002：Google Docs 章節偵測採雙層策略（font-size 主、text pattern 副）

## 狀態
已採納（Accepted）

## 日期
2026-06-22

## 背景
Google Docs import 透過 `/mobilebasic` route 取得 HTML，需從中偵測章節邊界。初版只用文字 pattern matching（`chapterTitlePattern` regex 白名單 + `chapterMarkerCount` 拒絕多章節 TOC 行）。

使用者匯入一篇含「特別篇一～十二」、「作者的信」、「第一幕：擁抱。」等非標準章節命名的真實小說後，發現：

1. **特別篇/作者的信完全消失**：不在 `chapterTitlePattern` 白名單 → splitter 看不到
2. **幕 sub-sections 顯示為 "Patreon post"**：標題 "第一幕：擁抱。" 含 "。" → `ChapterTextFormatter.looksLikeBodyText` 回 true（無長度門檻）→ contamination 路徑 → `URLNormalizer` 對 Google Docs URL 回 nil → fallback 為空 → 顯示 "Patreon post"
3. **使用者明確指出**：text pattern 做法本質上脆弱，不同作者的章節命名千變萬化，白名單永遠追不完

核心限制：文字 pattern 是 **open-ended problem**（無窮多合法章節標題），但 Google Docs mobilebasic 的**視覺格式是封閉的**（大字 = heading，小字 = body）。

## 決策
採雙層偵測策略，在 `detectChapters()` 的 paragraph loop 中：

```swift
guard let title = chapterTitleParagraph(rawInner) ?? largeFontTitle(rawInner) else { continue }
```

### Layer 1（fallback 但優先執行）：Text pattern — `chapterTitleParagraph`
- 已知章節 pattern 的精確匹配（第N章/回/節/篇/卷/部/幕、序章、楔子、特別篇、番外篇、作者的信/話、附錄、結語、chapter N、prologue/epilogue）
- `chapterMarkerCount > 1` 拒絕 TOC 行（涵蓋 第N章 + 特別篇N + 番外篇?N + chapter N）
- 適用場景：未套用 Heading style 的 Google Docs、其他純文字 HTML

### Layer 2（主要機制）：Font-size — `largeFontTitle`
- 偵測 `<span style="font-size:Npt">` 且 N ≥ 18
- 不檢查文字內容是否匹配任何 pattern
- 用 ≤ 40 字元 + 無 `<a>` / `<br>` 來排除 body text 和 TOC 連結
- 適用場景：有套用 Heading/Title style 的 Google Docs（絕大多數）

### 配套：`stripTrailingPunctuation`
- 去除 。！？.!? 尾部標點
- 防止 `looksLikeBodyText` 的 "。" 觸發 → "Patreon post" 連鎖
- 應用於所有 boundary title 輸出（heading、text pattern、font-size）

`??` 鏈讓 text pattern 優先：同一個 paragraph 若兩者都匹配，text pattern 產出更精確的 title（不含 HTML style 屬性殘留）。Font-size 只在 text pattern 不認識時才接手。

## 考慮過的替代方案

### 只擴充 text pattern 白名單
- 優點：最小改動，不需解析 HTML style
- 缺點：永遠追不完。使用者說：「之後如果別篇文章的章節取名比較特別，這個規則就會失效」。每次遇到新命名就要加 pattern、發版、使用者更新。
- 否決：根本設計問題，不是缺 pattern 數量的問題

### 修改 `ChapterTextFormatter.looksLikeBodyText` 加長度門檻
- 優點：直接修 "Patreon post" 的顯示問題
- 缺點：`isProbablyContaminatedTitle("這是一段內文。")` 既有測試期望 7 字元含 "。" 的字串回 true。加長度門檻會破壞此行為。且 formatter 的邏輯對 Patreon scrape 場景是正確的——問題出在 splitter 產出不該帶 "。" 的 title。
- 否決：在源頭（splitter）修比在下游（formatter）修更乾淨

### Source-aware fallback title（formatter 區分 Google Docs vs Patreon）
- 優點：Google Docs 章節永遠不會 fallback 到 "Patreon post"
- 缺點：需在 `LocalChapterModel` 或 display chain 帶 source kind，改動跨多層（store → model → formatter → view）
- 否決：`stripTrailingPunctuation` 更簡單地解決了同一個問題，不需跨層改動

### 用 heading tag（h1-h6）而非 font-size
- 優點：語義正確的 HTML heading
- 缺點：Google Docs mobilebasic 經常不用 heading tag，改用 `<p>` + inline `font-size`。既有 `detectChapters` 已處理 h1-h3；font-size 偵測是補這個缺口。
- 否決：不是替代，是互補。兩者都保留。

## 後果
- 大多數 Google Docs 的章節偵測不再依賴文字內容白名單。任何 ≥ 18pt 的短文本自動成為章節邊界。
- 白名單仍有價值：(1) 無 style 的 plain text HTML，(2) 在 `??` 鏈中產出更乾淨的 title。
- 18pt 門檻可能遺漏 Heading 2（~16pt）級別的章節。目前可接受——H2 通常是章節內子標題，不是章節邊界。若遇到 H2 當章節邊界的文件，調低門檻即可。
- 若 Google Docs 改變 mobilebasic 的 HTML 格式（不再用 inline font-size），Layer 2 失效但 Layer 1 仍在。
- `stripTrailingPunctuation` 是全域套用（所有 boundary title），可能去掉作者刻意的藝術性標題尾標點（如「結局。」→「結局」）。目前可接受——編輯慣例上章節標題不帶句號。
