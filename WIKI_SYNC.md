# WIKI_SYNC

> 來源 project: monori
> 產出日期: 2026-08-12
> 同步目標: knowledge-wiki/wiki-pages/専案管理/

使用方式：在 knowledge-wiki session 中執行「専案管理 update」，將以下內容分別寫入對應路徑。

---

## errors/（踩過的坑）

**error_wkwebview-default-ua-blocks-google-oauth.md 建議內容：**

```
## 症狀
App 內嵌 WKWebView 開第三方網站的登入頁，「Continue with Google」按鈕呈現停用（灰色），
點下去完全沒反應：沒有 popup、沒有 JS error、連 window.open 都沒被呼叫。
同一頁的 Apple / Facebook 登入正常。

## 根因
WKWebView 的預設 User-Agent 停在 `Mobile/15E148`，不帶 `Version/` 也不帶 `Safari/` token：

    Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148

Google 以此判定為 embedded webview，對 Google Identity Services 的 SDK
`https://accounts.google.com/gsi/client` 直接回 403。網站的 Google 登入按鈕拿不到 SDK，
就渲染成停用狀態。這是 Google 針對「會對頁面注入 JS 的 app」的防釣魚保護，不是 bug。

## 修法
先確認是不是這個原因（只換 UA，其他不動）：

    curl -s -o /dev/null -w "%{http_code}\n" -A "<app 的 UA>" https://accounts.google.com/gsi/client
    curl -s -o /dev/null -w "%{http_code}\n" -A "<Safari 的 UA>" https://accounts.google.com/gsi/client

403 對 200 就確定了。兩條路：

1. 合規路線：告訴使用者這個環境不支援 Google 登入，引導去真正的瀏覽器設定密碼或改用其他 SSO。
2. 讓 WebView 以 Safari 身分呈現：
   `config.applicationNameForUserAgent = "Version/18.7 Safari/604.1"`
   用 `applicationNameForUserAgent` 而非 `customUserAgent`，base UA 才會繼續跟著 WebKit 更新。
   `Version/` 要跟 WebKit 自己回報的 OS token 對齊（目前 `iPhone OS 18_7`），不是裝置的 iOS 版本。

選 2 要清楚知道代價：這是繞過 Google 的防釣魚檢查，Google 隨時可以加上 UA 以外的判斷再擋一次，
症狀會一模一樣。再次發生時不要靠加碼偽裝去對抗。

## 預防措施
- 寫一個測試釘住 UA 後綴同時含 `Version/` 與 `Safari/`，掉一個就紅燈。
- 診斷手法可複用：在 `WKWebViewConfiguration` 掛 `#if DEBUG` user script，
  包住 `window.open`、掛 capture 階段的 `error` listener（`e.target.tagName` 抓得到載入失敗的
  `<script>` / `<link>`）、覆寫 `console.warn/error`，再用
  `xcrun simctl launch --console-pty` 收 log。
- 一定要準備對照組。本案是「Apple 登入正常開 popup、Google 連 window.open 都沒呼叫」，
  才排除掉 popup 機制的嫌疑，直接指向 SDK 沒載入。

## 出現過的專案
- monori（2026-08-12）
```

---

## patterns/（可複用模式）

**pattern_webview-oauth-popup-host-allowlist.md 建議內容：**

```
## 問題描述
App 內嵌 WebView 承載第三方網站時，網站的 OAuth 登入用 `window.open` 開 popup，
並靠 `response_mode=web_message` postMessage 回 `window.opener`。
若把這類 URL 導去系統瀏覽器，或在原地載入而毀掉 opener，登入永遠無法完成。
而內容連結若一律給 popup，又會失去主 WebView 上的偵測 script 與功能列。

## 解法
分類的問題不是「這是哪個網站」，而是「這個 URL 需不需要真正的 popup window 語意」——
只有 OAuth 登入端點需要。

在 `WKUIDelegate.createWebViewWith` 裡：
- 通過導覽白名單的 URL，預設用 `webView.load(request)` 留在主 WebView
- 只有命中 OAuth 主機清單時才建立 popup WKWebView

兩份清單的比對嚴格度刻意不同：
- 導覽白名單用 suffix match（`.facebook.com`），因為 OAuth 流程會在
  `m.` / `www.` / `staticxx.` 之間跳，收窄成單一主機會讓登入半途壞掉
- popup 判定用精確主機比對，擋掉 `appleid.apple.com.evil.example` 這種 lookalike

每加一個 OAuth provider，兩份清單都要加，漏掉後者的失敗模式是「登入表單開不出來」。
測試要同時涵蓋正常主機、lookalike 主機、以及不該拿到 popup 的內容 URL。

## 目前使用專案
- monori（NavigationPolicy.decide / requiresPopupWindow，ADR-0007 + ADR-0008）
```

---

## adr/（架構決策）

**adr_identify-embedded-webview-as-safari.md 建議內容：**

```
## 背景
內嵌 WKWebView 的 app，若網站的登入流程依賴 Google Identity Services，
Google 會因為預設 UA 缺少 `Version/` 與 `Safari/` token 而回 403，登入按鈕變成死的。
限制條件：app 的所有功能都讀網站的 session cookie，
所以不能改用 `ASWebAuthenticationSession`（它對 custom callback scheme 驗證，
拿不到 cookie 放進 WKWebView）。

## 決策
用 `applicationNameForUserAgent` 補上 `Version/x Safari/604.1`，讓 WebView 以 Safari 身分呈現。

## 替代方案考慮
| 方案 | Pros | Cons | 拒絕原因 |
|------|------|------|---------|
| 維持預設 UA，改成引導使用者 | 不碰 Google 的防釣魚檢查 | 每個 Google 帳號使用者都要先繞到別的瀏覽器設密碼 | 專案擁有者權衡後選擇改 UA |
| 改用 ASWebAuthenticationSession | Apple 官方認可的 OAuth 途徑 | 拿不到網站 session cookie | 下游功能全部依賴 cookie，技術上不可行 |
| customUserAgent 寫死整串 UA | 完全控制 | base UA 不再跟著 WebKit 更新，OS token 會過期 | 維護成本高於收益 |

## 後果
Google / Apple / Facebook 登入都能在 app 內完成。
接受的風險：這是繞過 Google 針對「會對頁面注入 JS 的 app」的防釣魚保護，
Google 可隨時加上 UA 以外的判斷再擋，且不會事先通知。
再次失效時視為預期，改走引導路線，不要加碼偽裝。
另外，網站可能因此改送不同版本的頁面（本案 Patreon 換成完整版登入頁），
任何依賴該頁 DOM 結構的程式碼都要重新驗證。

## 目前狀態
active
```
