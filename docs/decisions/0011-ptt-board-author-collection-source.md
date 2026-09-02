# ADR-0011：PTT 以「同看板＋同作者」定義 Collection

## 狀態

已採納（Accepted）

## 日期

2026-08-26

## 背景

Monori 是 local-only 的閱讀殼層。現有來源以「collection → chapters」為核心模型，使用者在來源網站的 `WKWebView` 中瀏覽，再把章節目錄匯入本機書庫。Monori 不使用來源平台 API、不擷取 cookie、不攔截網路封包、不繞過存取控制，也沒有自己的內容後端。

PTT 適合作為新的 Web-based reading source。PTT Web 文章頁包含看板、作者、標題、發佈時間、正文與推文；看板頁與作者搜尋頁則提供文章列表。PTT 也提供看板內作者搜尋，例如：

`https://www.ptt.cc/bbs/{board}/search?q=author:{author}`

PTT 沒有 Monori 現有來源那種明確的「作品／系列」實體。作者可能使用章號、共同前綴、每章不同名稱、番外名稱，或完全沒有固定命名規則。若 Monori 嘗試從標題推斷系列，必須維護大量 heuristic，且任何未涵蓋的命名方式都可能造成漏收或誤收，直接影響匯入與追更體驗。

另一方面，PTT 文章本身有穩定的作者、看板與發佈時間。使用「同看板＋同作者」可建立 deterministic、可預測的 collection 規則，不需要理解作者的命名習慣。

## 決定

PTT 新增為 Monori 的 Web-based source，沿用 ADR-0003 採納的多來源擴展方式，不新增 plugin 或通用 adapter abstraction。

PTT collection 的 identity 固定為：

```text
board + author
```

也就是：

```text
同一個 PTT 看板
+
同一個 PTT 作者
=
一個 Monori collection
```

標題不參與 collection 判斷。Monori 不做標題 prefix、章號、regex、NLP、LLM、相似度或其他系列辨識。

### 匯入入口

使用者瀏覽 PTT 文章頁時，Monori 從目前 document 讀取：

- `board`
- `author`
- 文章標題
- canonical article URL
- 發佈時間

只要能取得合法的 `board` 與 `author`，就顯示匯入 banner。

使用者匯入後，Monori 載入該作者在該看板的 PTT Web 搜尋頁：

```text
https://www.ptt.cc/bbs/{board}/search?q=author:{author}
```

並從搜尋結果取得該 collection 的文章列表。

collection 的顯示名稱預設使用能清楚表達來源範圍的名稱，例如：

```text
{author} · {board}
```

若現有 Library 已支援 collection rename，使用者可自行改名；PTT adapter 不推斷作品名稱。

### 章節定義與排序

每篇未刪除、具有可開啟 article URL 的搜尋結果視為一個 chapter。

chapter title 使用 PTT 原始文章標題，不做系列名稱解析或標題正規化。

章節順序以文章的實際發佈時間由舊到新排列：

```text
oldest → newest
```

「上一章／下一章」完全依此排序。

PTT 列表頁顯示的 `M/D` 只適合列表顯示，不應成為跨年度排序的唯一資料。實作應優先從文章頁 metadata 取得完整發佈時間；如果目前架構的 import flow 不適合逐篇載入 metadata，coding agent 必須先確認 PTT article URL 中的 Unix timestamp 是否可作為穩定的排序 key，並用 fixture / live DOM 驗證後再採用。不得只用月／日猜年份。

### Refresh / 追更

PTT 支援 auto-check。

refresh 時重新載入該 collection 的 author-search URL，取得目前所有可見 article URLs，並與本機 collection 既有 chapter URLs 做 identity diff：

- 已存在 URL：不重複加入
- 新 URL：加入為新 chapter，依既有 Library 規則標記未讀
- 搜尋結果中暫時看不到的舊 URL：不得因此刪除本機 chapter

collection refresh 仍以 `board + author` 為唯一匹配條件，不分析文章標題。

### Reader

PTT 使用 Web-based reader，文章內容仍從 `ptt.cc` 在 `WKWebView` 載入，不把全文同步到 Monori server。

新增 PTT 專用 reader ruleset，目標是保留：

- 文章標題
- 作者／必要 metadata
- 正文
- 正文中的連結與圖片

並隱藏或弱化：

- PTT 全站 navigation / chrome
- 看板操作列
- 推文區
- 其他不屬於主要長文閱讀內容的控制項

V1 預設不把推文視為正文，也不把推文轉成 chapter metadata。

Reader selector 必須以 PTT 實際 live DOM 與 HTML fixture 驗證，避免依賴純視覺 class 名稱；如果 selector 失效，沿用 Monori 既有 graceful fallback，退回原始頁面而非顯示空白 Reader。

### 18+ 看板

Monori 不自行寫入、偽造或攔截 PTT 的 age-gate cookie。

如果 PTT 顯示年齡確認頁，使用者在網站自己的 UI 中自行確認，由正常 `WKWebView` session 保存網站狀態。Monori 不自動代替使用者確認。

### Source integration

PTT 應沿用現有 source pattern，至少涵蓋：

- `SourceKind` 新增 `.ptt`
- `SourceRegistry` 新增 PTT provider，start URL 指向 `https://www.ptt.cc`
- `supportsAutoCheck` 包含 `.ptt`
- `NavigationPolicy` 允許 `ptt.cc` / `www.ptt.cc` 正常留在 WebView
- `URLNormalizer` 新增 PTT board / article / author-search URL 辨識與 canonicalization
- PTT article detect script
- PTT author collection import script
- PTT Reader CSS ruleset
- `AppEnvironment` 建立 PTT 專用 `WebViewModel`，維持來源間 session 隔離
- Browse source picker / Library source glyph 加入 PTT
- 依 `DESIGN.md` 使用 Monori 自有 `SourceGlyph` 規則，不以 SF Symbol 當成最終品牌／來源 glyph
- 對 PTT URL、DOM extraction、import dedupe、排序、refresh merge、Reader selector 加測試

實際檔名與掛載位置以實作時 repo 最新結構為準；不要為了 PTT 新增第二套 source architecture。

## 考慮過的方案

### 方案 A：同看板＋同作者（✅ 採納）

- 優點：規則 deterministic，可由使用者理解；作者改章節名稱不會造成漏章；refresh 不需要重新推斷系列；不依賴 AI 或命名 heuristic。
- 缺點：同一作者在同一看板同時發表多個系列或其他文章時，會全部出現在同一 collection。
- 採納原因：這個限制穩定、可預期。對 Monori 而言，可預測的粗粒度 collection 優於會漏章或誤判的自動系列辨識。

### 方案 B：同看板＋同作者＋標題 pattern

例如共同 prefix、章號、`第 N 章`、regex 等。

- 優點：可把同作者的多個系列拆成不同 collection。
- 缺點：作者命名沒有固定規範；需要持續擴充 heuristic；例外會直接造成漏章或誤收；refresh 結果可能因規則演進而改變。
- 否決原因：設計過於脆弱，無法涵蓋所有作者命名方式。

### 方案 C：NLP / LLM 判斷同系列

- 優點：理論上可處理語意相關但字面不同的標題。
- 缺點：結果 nondeterministic；增加網路、成本、延遲與 privacy 邊界；難以測試與 debug；仍不能保證正確。
- 否決原因：問題可用穩定的 `board + author` identity 解決，沒有引入模型的必要。

### 方案 D：整個看板是一個 collection

- 優點：實作最簡單。
- 缺點：大量互不相關文章混在一起，失去 Monori collection 的閱讀語意。
- 否決原因：粒度過粗。

### 方案 E：單篇文章是一個 collection

- 優點：完全不需要系列判定。
- 缺點：失去 chapter navigation、追更與 collection 的主要價值，Library 會快速膨脹。
- 否決原因：不符合 Monori 的核心閱讀模型。

## 後果

- PTT source 的核心規則只有 `board + author + published time + article URL`，不需要維護 title clustering。
- 作者在同看板發表的其他系列、公告或獨立文章也會進入同一 collection；這是已接受的產品 trade-off，不應在實作中偷偷加入 title filter 修正。
- PTT import / refresh 依賴網站 Web HTML 與 DOM，網站改版時可能失效；必須以 fixture tests 和 graceful fallback 控制風險。
- PTT collection 可直接接上現有 Library、未讀標記、上一章／下一章與 auto-check。
- PTT 不新增後端、不使用 PTT API、不擷取 cookie、不繞過 age gate 或其他存取控制，維持 `COMPLIANCE.md` 的既有產品邊界。
- 未來若要支援「同作者拆成多個系列」，應另寫新的 ADR supersede 本決策；不要在本 ADR 的實作中逐步加入隱性 heuristic。
