# WIKI_SYNC

> 來源 project: Monori
> 產出日期: 2026-09-03
> 同步目標: knowledge-wiki/wiki-pages/専案管理/

使用方式：在 knowledge-wiki session 中執行「専案管理 update」，將以下內容分別寫入對應路徑。

---

## errors/（踩過的坑）

**error_fixture-invented-selector.md 建議內容：**
```
## 症狀
匯入腳本的單元測試全綠（15/15），但對真實網站跑，所有章節的內文欄位都是空的；reader 因此退回載入整頁。

## 根因
測試 fixture 的 HTML 是人手寫的，內文容器用了自己捏造的 class（`.post-body`），程式碼直接依賴這個 class。真實 DOM 從未驗證過這個 class 是否存在。fixture 與程式碼互相印證，測試證明不了任何事。

## 修法
1. 從真實頁面取得結構（本例：目標 SPA 在自動化瀏覽器不渲染，改從 App 本機資料庫已存的 HTML 只印 tag／class 結構）。
2. fixture 改成鏡射真實結構；程式碼改取確認存在的容器（`div.content`），並加「排除已知 chrome」的 fallback，不依賴單一未驗證 class。
3. 測試同時斷言「正文在」與「chrome 不在」（留言區、登入提示、編輯戳）。

## 預防措施
- fixture 必須標明來源與擷取日期；捏造的部分要在註解裡說明「未驗證」。
- selector 上線前至少用一份真實擷取驗證；驗證不到就用排除法或多重 fallback。
- 匯入後在 log 記「N 章中 M 章有內文」這類安全計數，讓空結果第一次跑就被看到。

## 出現過的專案
- Monori（2026-09-03，slashtw／Waterfall 匯入）
```

---

## patterns/（可複用模式）

**pattern_discuz-archiver-plain-html.md 建議內容：**
```
## 問題描述
Discuz 論壇遷移到 SPA 前端（或本身就是 SPA 包 Discuz 資料）後，自動化瀏覽器打開討論串只看到 loading spinner，讀不到版規、公告等純文字內容。

## 解法
Discuz 的 archiver 模式會輸出無 JS 的純 HTML：`https://<host>/archiver/?tid-<N>.html`。用它讀正文第一樓即可拿到規則全文；翻頁參數（`?page=N`、`-page-N`）在某些站無效，只回第 1 頁，但公告類內容通常都在第一樓。

## 目前使用專案
- Monori（讀 slashtw 版規，2026-09-03）
```

---

## adr/（架構決策）

**adr_read-actual-rules-before-compliance-call.md 建議內容：**
```
## 背景
新增第三方內容來源時，要決定「本機儲存內容」還是「只做 Web-based 呈現」。前一個 session 沒有讀到平台版規，寫了一份「灰色地帶，保守處理，Web-based」的 ADR。後續實作發現 Web-based 在技術上做不到單章顯示，而且另一個 session 已經默默改成存 HTML，跟 ADR 與 COMPLIANCE 文件互相矛盾。

## 決策
合規判斷必須以實際讀到的條文為依據。「查不到條款所以保守」的結論只能標記為暫定，不能當成已裁決的政策沿用；發現既有結論沒有引用條文時，先去讀（本例用 Discuz archiver 取得純 HTML），引用原文後再把選項交給使用者用可點選的問題決定，並同步修 ADR 與合規文件。

## 替代方案考慮
| 方案 | Pros | Cons | 拒絕原因 |
|------|------|------|---------|
| 沿用既有保守 ADR | 不用再查 | 結論沒有事實依據；技術上做不到需求 | 使用者指出 ADR 是未讀版規寫的 |
| 直接改成存 HTML、不改文件 | 快 | 程式行為與 COMPLIANCE 矛盾，日後審查會被抓 | 政策反轉必須留紀錄 |
| 讀完條文再決定（採用） | 決策有依據；風險與緩解寫進 ADR | 多花一輪查證 | 無 |

## 後果
- 版規實際只禁止「轉載／轉出並發表」，個人本機副本不在其中；決策反轉為存 HTML，剩餘風險（板務從寬解讀、作者刪文後副本仍在、分級權限）寫進 ADR 與 COMPLIANCE。
- 專案 memory 新增 feedback：合規判斷前先讀實際條文。

## 目前狀態
active
```
