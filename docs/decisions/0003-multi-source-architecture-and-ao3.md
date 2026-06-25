# ADR-0003：多來源架構與 AO3 閱讀入口

## 狀態
已採納（Accepted）

## 日期
2026-06-25

## 背景
Monori 目前支援兩個閱讀來源：Patreon（Web-based，JS 抓取章節匯入）與 Google Docs（本地 HTML 儲存，章節分割）。使用者希望新增三個來源：AO3（Archive of Our Own）、方格子（vocus）、AsianFanfics。

本 ADR 記錄本次 session 做出的所有設計決策，包括被否決的方案及其理由。

---

## 決策 1：Reader 模型（本地儲存 vs Web-based）

### 前置研究：三平台使用條款分析

在做決定前，先研究了三個平台的使用條款：

| 平台 | 本地儲存 HTML | Web-based 載入 |
|------|:---:|:---:|
| AO3 | 🟢 可行（官方有下載功能；明確允許非商業第三方 App） | 🟢 可行 |
| vocus | 🔴 條款禁止（「以程式重製」明文禁止） | 🟢 可行 |
| AsianFanfics | 🟡 灰色地帶（官方離線功能是作者可控 opt-in） | 🟢 可行 |

### 決定
AO3 用本地 HTML 儲存（類似 Google Docs 路徑），vocus 與 AsianFanfics 用 Web-based（類似 Patreon 路徑）。

### 考慮過的方案

#### 方案 A：全部 Web-based（像 Patreon）
- **優點：** 最簡單、最安全、無 ToS 風險。不需要寫 HTML 萃取邏輯。
- **缺點：** AO3 有官方下載功能且明確允許，放棄離線讀取可惜。每次閱讀都需要網路連線。
- **否決原因：** AO3 條款明確允許，沒理由放棄更好的使用者體驗。

#### 方案 B：AO3 本地、其他 Web-based（✅ 採納）
- **優點：** 在 ToS 允許的範圍內最大化使用者體驗。AO3 可離線讀取。vocus/AFF 不碰 ToS 紅線。
- **缺點：** 兩條 reader 路徑（但已經存在：Patreon vs Google Docs）。

#### 方案 C：全部本地儲存（像 Google Docs）
- **優點：** 統一路徑，全部可離線。
- **缺點：** vocus 條款明文禁止「以程式重製」。AsianFanfics 繞過作者可控的離線功能設計。法律風險。
- **否決原因：** vocus ToS 明確禁止，不值得冒險。

#### 方案 D：延後決定，架構同時支援兩種
- **優點：** 彈性。
- **缺點：** 延後不等於不決定，只是增加 scope。
- **否決原因：** 資訊已足夠做決定。

---

## 決策 2：多來源架構方案

### 決定
方案 A：沿用現有模式擴展。

### 考慮過的方案

#### 方案 A：沿用現有模式擴展（✅ 採納）
每個 source 沿用已驗證的模式：
1. `SourceKind` enum 加 case
2. `SourceRegistry` 加 provider
3. AppEnvironment 加 lazy `WebViewModel`
4. `NavigationPolicy` 加網域白名單
5. `URLNormalizer` 加該站 URL 解析
6. 站點特定的 JS/splitter

- **優點：** 沿用已驗證的架構，改動點明確。每個 source 隔離。加新 source 範圍好控制。
- **缺點：** `NavigationPolicy`/`URLNormalizer` 隨 source 數線性成長。AppEnvironment 最終有 5+ lazy WebViewModel。
- **採納原因：** 真正的複雜度在站點特定的 DOM/JS 邏輯，protocol 或 plugin 無法簡化。5 個 source 量完全可控。

#### 方案 B：Source 協定抽象層
定義 `SourceAdapter` protocol（`canImport`、`detectCollection`、`importChapters`），每個 source 各自實作，`SourceManager` 根據 URL 路由。

- **優點：** 結構清楚、單元測試容易。未來加 source 不碰 switch/if。
- **缺點：** 目前邏輯本身就很簡單（switch on SourceKind），protocol 多了間接層，除錯更難追。真正的複雜度（每站的 JS/HTML 解析）protocol 無法簡化。
- **否決原因：** 對 4-5 個 source 是過度抽象。

#### 方案 C：Plugin 式架構
Source 變成可載入模組，用設定檔定義（網域 pattern、JS 腳本、CSS）。

- **優點：** 最大擴展性，理論上不改 Swift 就能加 source。
- **缺點：** 5 個 source 嚴重過度工程。間接層讓除錯困難。沒有使用者會寫 plugin。每站 DOM 結構差異大，config-driven 抽象會漏洞百出。
- **否決原因：** 完全過度工程。

---

## 決策 3：匯入觸發方式

### 決定
Auto-detect（自動偵測），與現有 Patreon collection detection 一致。

### 考慮過的方案

#### 方案 A：Auto-detect（像 Patreon）（✅ 採納）
瀏覽到 work/專題/story 頁面時自動偵測並顯示匯入 banner。

- **優點：** 使用者體驗一致。不需要額外操作。
- **缺點：** 每個站需要寫偵測 JS。偵測可能有 false positive。

#### 方案 B：手動匯入按鈕
工具列常駐匯入按鈕，使用者手動觸發。

- **優點：** 簡單，不需要偵測邏輯。
- **缺點：** 使用者不知道什麼時候該按。與現有 Patreon 行為不一致。

#### 方案 C：Auto-detect + 手動 fallback
先自動偵測，偵測失敗時允許手動觸發。

- **優點：** 最靈活。
- **缺點：** 兩套觸發邏輯。
- **否決原因：** 先做 auto-detect，有需要再加 fallback。

---

## 決策 4：AO3 章節抓取策略

### 決定
策略 1：用 `/navigate` 頁面取章節列表 + 逐章 fetch HTML。

### 考慮過的方案

#### 策略 1：逐章抓取（✅ 採納）
Fetch `/works/{id}/navigate`（章節索引頁）解析章節列表，逐章 fetch HTML 萃取 `<div class="userstuff">` 內容。

- **優點：** 可顯示進度（「匯入中 3/15…」）。不觸發 AO3 rate limit（逐章 + delay）。每章有獨立 URL。`/navigate` 頁面輕量穩定。
- **缺點：** 多次 fetch（N+1）。需要處理 rate limiting delay。

#### 策略 2：一次抽全文
Fetch `?view_full_work=true` 拿到整篇，再用 chapter marker 分割。

- **優點：** 單次 fetch。類似 Google Docs splitter 模式。
- **缺點：** 長作品可能觸發 AO3 rate limit 或 timeout。無法顯示逐章進度。整頁 HTML 可能非常大。
- **否決原因：** rate limit 風險 + 無法顯示進度。

---

## 決策 5：上線順序

### 決定
AO3 → AsianFanfics → vocus。

### 理由
- **AO3 first：** 強制建立多來源基礎設施。有明確章節結構 + 官方下載先例。公開作品不需登入，易測試。
- **AsianFanfics second：** Web-based，明確章節列表，改動幅度適中。
- **vocus last：** 專題結構變化最大，偵測最困難。Web-only（ToS 限制）reader 路徑較簡單但匯入偵測較複雜。

---

## 決策 6：登入模型

### 決定
與 Patreon 相同：使用者手動在 in-app browser 登入，App 使用 WKWebView session 存取內容。

### 考慮過的方案

#### 方案 A：同 Patreon（手動登入）（✅ 採納）
- **優點：** 一致的使用者體驗。不需要實作 OAuth 或 API 整合。
- **缺點：** 每個 source 的登入是手動步驟。

#### 方案 B：僅支援公開內容
- **優點：** 完全不需要登入流程。
- **缺點：** 放棄大量需要登入才能看的內容（AO3 restricted works、vocus 付費文章、AFF 會員限定）。
- **否決原因：** 限制太大。

#### 方案 C：混合模式
支援登入但也能處理公開內容。
- **實質上等於方案 A**，因為 WKWebView 不需要登入也能載入公開頁面。

---

## 後果
- `SourceKind` enum 新增 `.ao3`、`.vocus`、`.asianFanfics` 三個 case
- `ImportedCollection` 需要加 `sourceKind` 欄位（`applyDocImport` 目前 hardcode `.googleDocs`）
- AO3 需要新的 `AO3ChapterSplitter`（解析 navigate + 章節頁）
- NavigationPolicy、URLNormalizer 需要 per-source 擴展
- 完整設計 spec 見 `docs/superpowers/specs/2026-06-25-multi-source-ao3-design.md`（gitignored，本地參考）
