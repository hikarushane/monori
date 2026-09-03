# ADR-0012：CXC 與在水裡寫字閱讀來源 ToS 分析

## 狀態
已接受（Accepted）。2026-09-03 修訂：在水裡寫字的 Reader 模型改為本地儲存 HTML，見文末。

## 日期
2026-09-02

## 背景
使用者希望新增兩個閱讀來源：CXC（Content x Creator 創利市集）與在水裡寫字（Written in Waters / slashtw）。依 ADR-0003 建立的流程，新增來源前必須先做使用條款分析，決定 Reader 模型（本地 HTML 儲存 vs Web-based）。

---

## 平台概述

### CXC（Content x Creator 創利市集）

- **網站**：cxc.today（子域名：bl.cxc.today 等分類）
- **類型**：台灣數位內容販售平台，創作者開店、讀者瀏覽購買
- **營運公司**：創利內容股份有限公司（Revecon Co., Ltd），統編 91009698
- **內容類型**：漫畫、小說、插圖、聲音作品
- **存取控制**：免費章、追蹤限定章、付費章
- **URL 結構**：
  - 作品頁：`cxc.today/zh/@{username}/work/{workId}`
  - 章節閱讀：`cxc.today/zh/@{username}/work/{workId}/chapter/...`
  - 分類子域名：`bl.cxc.today`、`bg.cxc.today` 等

### 在水裡寫字（Written in Waters）

- **網站**：slashtw.space（舊版 Discuz）→ waterfall.slashtw.space（新版 Waterfall）
- **類型**：台灣繁體中文同人/原創小說論壇，2015 年成立
- **營運**：社群經營，非商業公司
- **內容類型**：同人文、原創文、圖文、企劃
- **存取控制**：遊客可讀主文（2026-09-03 於 App WebView 未登入狀態實測樓層可渲染；`needLogin` 只掛在目錄側欄）。R 級以上文章需積分 >20。原文「新版需登入才能閱讀」為誤判
- **URL 結構**：
  - 舊版：`slashtw.space/forum.php?mod=viewthread&tid={id}`
  - 新版：`waterfall.slashtw.space/thread/{id}`
- **平台遷移**：正從 Discuz 遷移到自製 Waterfall 平台

---

## 決策：Reader 模型

### 使用條款分析

| 平台 | 本地儲存 HTML | Web-based 載入 |
|------|:---:|:---:|
| CXC | 🔴 條款禁止 | 🟢 可行 |
| 在水裡寫字 | 🟢 版規未禁止（2026-09-03 查核，見文末修訂） | 🟢 可行 |

### CXC — 條款禁止本地儲存

CXC 服務條款第八條第 3 項（版本 4.1，2024/6/7 更新）：

> 除本公司提供之功能外，您不得使用任何軟體或工具，試圖側錄或擷取本公司軟體或程式、網站上之所有內容，進行散佈或另行存取內容之副本。本公司如有發現您有上述行為，得不待通知即永久停用您使用本公司服務之權利，不提供退款，並將相關資料提供予權利受侵害之人。

同條款第五條第 4 項：

> 會員服務中之各類文字、圖檔、圖片及其他著作或資料⋯⋯未經事前授權，您不得將這些⋯⋯為重製⋯⋯亦不得上載於其他任何網站、或以其他方式提供予其他人使用。

分析：與方格子「以程式重製」的禁止一樣明確。CXC 同時禁止「側錄或擷取」和「另行存取內容之副本」，使用外部工具做本地 HTML 儲存直接違反此條款。

### 在水裡寫字 — 灰色地帶，保守處理（已由 2026-09-03 修訂取代）

> 下列分析寫於尚未讀到版規的時候，判斷依據是「無法取得條款」。版規實際查核結果見文末修訂。

- 論壇板規需登入才能閱讀，無法取得完整公開條款。
- 新版 Waterfall 平台需登入才能閱讀內容。
- 內容為個別作者的創作，版權屬個別作者。
- 論壇未提供官方下載功能或 API。
- 社群經營的同人論壇，規模小、無商業授權機制。

分析：沒有明確禁止，但也沒有明確允許。與 AsianFanfics 的灰色地帶類似，但 slashtw 更小、更社群導向。保守做法是 Web-based，避免在未取得社群共識前將個別作者的創作存到外部 App。

### 決定

- CXC：**Web-based**（類似 Patreon/Vocus/AFF 路徑）。
- 在水裡寫字：原決定 Web-based，**2026-09-03 修訂為本地儲存 HTML**（AO3 路徑），理由見文末。

---

## 決策：登入模型

與 Patreon 相同：使用者手動在 in-app browser 登入。CXC 使用帳號密碼登入；slashtw 同樣使用帳號密碼登入。兩者的認證與存取控制由各自平台把關。

---

## 決策：Collection 對應

### CXC
一個「作品」（work）= 一個 Collection。作品頁有明確的章節列表，每個章節有獨立 URL。結構與 Patreon 的 collection 幾乎一致。

### 在水裡寫字
一個「主題」（thread）= 一個 Collection。論壇的結構是：
- 板（board）= 分類
- 主題（thread）= 一個作品
- 樓層（post）= 章節或作品本文

需要在實作時研究主題內的章節分割方式（可能是回覆分章、可能是單篇長文、可能用分隔線分章）。

---

## 決策：上線順序

CXC → 在水裡寫字。

理由：
- CXC 有明確的作品/章節結構，URL 可預測，現代 Web App。
- slashtw 正在遷移平台（Discuz → Waterfall），URL 結構不穩定，論壇結構需要更多研究。

---

## COMPLIANCE 影響

需更新 `COMPLIANCE.md`：
- 新增 CXC 和在水裡寫字的行為描述段落。
- CXC 為 Web-based，不存本地 HTML，與 Vocus/AFF 的描述格式一致。
- 在水裡寫字自 2026-09-03 起存每一樓的內文 HTML（sanitize 後、僅本機、不進 iCloud 備份），描述格式比照 AO3。
- 「平台條款與政策風險」段落需加入兩個新平台。

---

## 後果

- `SourceKind` enum 新增 `.cxc` 和 `.slashtw` 兩個 case
- CXC 用 Web-based reader（Patreon/Vocus 路徑）；在水裡寫字走 `applyDocImport` 的 stored-HTML 路徑（AO3 路徑），不需要新的 ChapterSplitter
- NavigationPolicy、URLNormalizer 需要 per-source 擴展
- 需要偵測 JS 和 reader CSS（per-source）
- slashtw 的章節分割邏輯待實作時確認

---

## 2026-09-03 修訂：在水裡寫字 Reader 模型改為本地儲存 HTML

### 觸發原因

實作後在 Simulator 實測 `waterfall.slashtw.space/thread/96958`（共 14 樓）發現 Web-based 路徑做不到「一樓＝一章」：

- 所有樓層共用同一個討論串網址，只有 `#post{id}` 錨點不同。WKWebView 回報的網址不含錨點，reader 無法用網址區分或單獨載入一章。
- Reader 載入討論串網址會顯示整串（登入卡、目錄、全部樓層），reader CSS 只能靠隱藏其他元件硬做。
- Waterfall 是 Vue SPA，樓層以無限捲動懶載入，初始只渲染約 5 樓。要顯示第 N 樓得先捲到底觸發載入。同日在三個自動化瀏覽器環境（桌面 Chrome 已登入、Claude Browser 桌面、Claude Browser 手機 UA）SPA 全部停在 loading 不出樓層，這條路徑的可靠度不足以當閱讀器。

### 版規查核

- 來源：`https://slashtw.space/forum.php?mod=viewthread&tid=2`（[公告] 板規與文章發表注意事項，260622 更新），2026-09-03 透過 Discuz archiver 讀取正文第 1 樓全文。
- 與「把內容帶出論壇」有關的條文只有兩條：
  - 二、發表規範 1：「禁止無斷轉載創作。」
  - 三、轉載/翻譯規範 2-1：「從本論壇轉出他人創作，請自行以私訊或其他聯絡方式，徵求原作者同意，不可只在留言告知轉錄意願。」違者初犯刪文，再犯公告 ID，三犯永久禁言。
- 規範對象是「轉載／轉出並發表到其他地方」。版規沒有任何條文涉及個人離線副本、快取、閱讀工具、爬蟲或第三方 App。
- 管理員（2015-07-20 回覆）表明論壇「除了嚴重侵權行為外，傾向於不做太多的限制與規範」，遊客可讀主文，且不打算關閉。
- 論壇沒有獨立的服務條款。

### 判定

使用者把自己本來就能讀的樓層存在自己的裝置上、只供本人閱讀、不上傳、不分享、不匯出、不建立跨使用者內容庫，性質接近瀏覽器快取或「儲存網頁」，不是版規定義的轉載或轉出。原「灰色地帶」的判斷來自沒讀到條文，讀完後規則層面沒有禁止。

### 剩餘風險與緩解

1. 板務可能把「轉出」從寬解讀成任何複製出站。緩解：COMPLIANCE.md 明文記載本機副本的用途與限制；不做任何分享或匯出功能。
2. 作者「擁有其作品之修改、刪除權利」，作者在論壇刪文後使用者裝置上的副本仍在。AO3 路徑今天也是如此，但 slashtw 是小型同人社群。緩解：COMPLIANCE.md 記為已知限制；重新匯入以當下頁面內容覆蓋。
3. R 級以上文章需積分 >20。緩解：匯入只擷取該使用者 session 已渲染的內容，不繞過權限、不自動登入、不呼叫 API。

### 決定

在水裡寫字改用**本地儲存 HTML**（AO3 路徑）：匯入時擷取每一樓 `.card-content` 內的 `div.content`（正文；結構於 2026-09-03 從 App WebView 匯入的真實標記確認），略過 `.title`（討論串標題，僅 1F）、`.subtitle`（章節標題列）與 `.comments`（留言區、登入提示、投餵按鈕），並去掉 Discuz 的 `i.pstatus` 編輯戳；標記改變、找不到 `.content` 時退回排除法。內容經 `HTMLSanitizer` 移除 script／style／iframe／object／embed／meta、inline event handler、`javascript:` 與 `data:` 連結後存為 `contentHTML`。Reader 以 `wrappedDocument` 渲染單章。`contentHTML` 依既有規則不進 iCloud 備份。

### 後果

- `SlashTWThreadImport.js` 回傳 `contentHTML`；`importSlashTWThread` sanitize 後交給 `applyDocImport`。
- 既有 library 裡 2026-09-03 前匯入的 slashtw 章節沒有內文，需重新匯入一次；`applyDocImport` 會以同網址合併並補上內文。
- 沒有 `contentHTML` 的章節維持 Web-based fallback（載入討論串網址），只是體驗差。
- `COMPLIANCE.md` §slashtw 改寫。
- Waterfall 正文容器為 `.card-content > div.content`，留言區為 `div.comments`，由 App 匯入的真實標記確認（自動化瀏覽器裡 SPA 不渲染，DevTools 無法用）。
