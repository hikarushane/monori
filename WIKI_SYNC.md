# WIKI_SYNC

> 來源 project: Chapterly
> 產出日期: 2026-06-19
> 同步目標: knowledge-wiki/wiki-pages/専案管理/

使用方式：在 knowledge-wiki session 中執行「専案管理 update」，將以下內容分別寫入對應路徑。

---

## errors/（踩過的坑）

**error_wkwebview-scrollview-bgcolor-reset.md 建議內容：**
```
## 症狀
設定 `WKWebView.scrollView.backgroundColor = .systemBackground` 後，dark mode 下頁面邊緣仍顯示錯誤底色（gray veil）。

## 根因
WKWebView 每次呼叫 `loadHTMLString()` 或 `load(URLRequest)` 後，內部會 reset
`scrollView.backgroundColor`，覆蓋掉開發者的設定。UIKit layer 雖然在設定後的 screenshot
看起來正確，但新頁面 load 後又還原。

## 修法
底色問題必須在 HTML/CSS 層解決，不能靠 UIKit：
- 在 `<html>` 使用 `<meta name="color-scheme" content="light dark">` 讓 WebKit 知道頁面支援雙色模式
- 在 CSS 設 `html, body { background: Canvas; }` 使用系統顏色
- 對有 hardcoded inline style 的 HTML（如 Google Docs export）需加 `* { background-color: transparent !important; }`

`webView.isOpaque = true` + `webView.backgroundColor = .systemBackground` 可作為 fallback
（防止極短暫 flash），但無法取代 CSS 修法。

## 預防措施
遇到 WKWebView 底色問題，先檢查 HTML/CSS 的 `background` 設定，不要只看 UIKit layer 的 backgroundColor。

## 出現過的專案
- Chapterly（2026-06-19）
```

---

**error_evaluatejavascript-diagnostic-ordering.md 建議內容：**
```
## 症狀
在 WKWebView 頁面處理函式中插入診斷 JS（用 evaluateJavaScript 讀 computed style），得到的
結果顯示「白底/正常」，但頁面實際渲染與使用者肉眼看到的不符。

## 根因
WKWebView.evaluateJavaScript() 是非同步排隊。若診斷 JS 排在 injectionScript() 之前，
它拿到的 computed style 是 CSS injection 執行前的狀態；injection 還沒跑，頁面還是原始樣式。
injection 之後頁面變色，兩者結果不一致，產生誤導性診斷。

## 修法
診斷 JS 必須排在所有 injection 之後：
  webView.evaluateJavaScript(injectionScript(), completionHandler: nil)
  webView.evaluateJavaScript(diagnosticScript, completionHandler: nil)  // 放後面

或在 injectionScript 的 completionHandler 中觸發診斷。

## 預防措施
插入 WKWebView 診斷時，始終確認它在 injection 之後排隊。
「CSS 診斷顯示正常但頁面看起來不對」= 幾乎可以直接懷疑診斷排序問題。

## 出現過的專案
- Chapterly（2026-06-19，Bug 4 gray veil debug session）
```

---

## patterns/（可複用模式）

**pattern_wkwebview-dark-mode-css.md 建議內容：**
```
## 問題描述
WKWebView 嵌入自訂 HTML 時，dark mode 下邊緣或頁面背景顯示系統預設灰色（gray veil），
或 hardcoded 顏色在深色模式下不可讀。

## 解法
在 HTML wrapper 中：

1. meta tag（在 <head> 最早處，WebKit 比 CSS 更早讀它）：
   <meta name="color-scheme" content="light dark">

2. CSS :root 宣告：
   :root { color-scheme: light dark; }

3. 用 CSS 系統顏色取代 hardcoded 值：
   html, body { background: Canvas; color: CanvasText; }

4. 若載入的 HTML 有 hardcoded inline style（如 Google Docs export），加：
   * { color: CanvasText !important; background-color: transparent !important; }
   html, body { background: Canvas !important; }

5. UIKit 層可加 fallback（防首幀 flash）：
   webView.isOpaque = true
   webView.backgroundColor = .systemBackground
   但這無法取代 CSS 修法（loadHTMLString 後 scrollView.backgroundColor 會被 reset）。

## 目前使用專案
- Chapterly（ReaderStyler.wrappedDocument()，2026-06-19）
```
