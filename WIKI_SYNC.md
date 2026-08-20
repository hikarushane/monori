# WIKI_SYNC

> 來源 project: Monori
> 產出日期: 2026-08-20
> 同步目標: knowledge-wiki/wiki-pages/専案管理/

使用方式：在 knowledge-wiki session 中執行「専案管理 update」，將以下內容分別寫入對應路徑。

---

## errors/（踩過的坑）

**error_css-cascade-inherit-breaks-spa-layout.md 建議內容：**
```
## 症狀
在 WKWebView（或一般瀏覽器）注入 CSS，想讓 dark mode 背景色套用到整個內容區時，用 `body > *, body > * > *, ...`（多層子孫選擇器）搭配 `background-color: inherit !important` 級聯下去。套在傳統 server-rendered 頁面上正常，但套在 React/Vue 等 SPA 頁面上，內容整個變成空白（不是顏色錯，是整個消失）。

## 根因
SPA 框架的中間容器往往依賴自己的 background-color（或相關的合成/z-index/backdrop 行為）維持版面結構，暴力用 `!important` 覆寫所有中間層的 background-color 會連動破壞框架本身依賴該樣式運作的部分，不只是「顏色被蓋掉」而是「版面壞掉」。

## 修法
不要對整個 DOM 樹套用暴力級聯。改用 JS 動態定位「實際內容容器」（例如用一個穩定的 class/data-attribute 找到文章本體），只沿著這個容器的祖先鏈（`parentElement` 往上走到 `document.documentElement` 為止）逐一 `style.setProperty('background-color', 'transparent', 'important')`，不去動容器本身以外的任何元素。

## 預防措施
- 同一份「暗色模式背景修復」邏輯，先確認目標頁面是 server-rendered 還是 SPA（React/Vue/等），兩者不能套同一種修法
- 有效的 CSS 級聯寫法（server-rendered 頁面安全）可以先在 SPA 頁面小範圍測試（單一文章頁），不要假設所有頁面同構
- 若一注入 CSS 就整頁空白（不是顏色錯），優先懷疑是不是背景/顯示相關屬性的級聯把框架依賴的樣式覆寫掉了，而不是选择器打錯

## 出現過的專案
- Monori（2026-08-20）：`ReaderRuleset.css` 對 Patreon（React SPA）套用跟 `VocusReaderRuleset.css`（server-rendered）相同的 6 層背景級聯，導致 Patreon 文章 dark/light 模式皆空白
```

---

## patterns/（可複用模式）

**pattern_webview-dark-mode-diagnosis.md 建議內容：**
```
## 問題描述
WKWebView（或一般瀏覽器）注入 CSS 想支援 dark mode，結果部分頁面「看起來沒套用成功」——但實際除錯時容易誤判根因，因為「dark mode 沒生效」這個症狀背後可能是三種完全不同層次的問題疊加，只查一層會漏掉其他層。

## 解法
排查 WebView dark mode CSS 問題時，用一段診斷 JS 一次拿到三層資訊，不要只看畫面判斷：
```js
(function(){
  var dm = window.matchMedia('(prefers-color-scheme: dark)').matches;
  var cs = getComputedStyle(document.documentElement).colorScheme;
  var bg = getComputedStyle(document.body).backgroundColor;
  var tc = getComputedStyle(document.body).color;
  return 'darkMatch=' + dm + ' colorScheme=' + cs + ' bodyBg=' + bg + ' bodyColor=' + tc;
})();
```
三層各自對應不同根因，不要合併診斷：
1. **`prefers-color-scheme` match 是否為 true** — 若為 false，問題在 `overrideUserInterfaceStyle`（native）或 `color-scheme` meta/CSS 屬性沒設對，跟後面兩層無關
2. **body 背景色是否正確** — 若 body 本身背景對但畫面看起來還是錯的，問題不在 body，要往下查中間容器（第 3 層以外，還要額外查 `getComputedStyle` 中間節點）
3. **body 文字色是否正確** — 常見錯法：`* { color: inherit !important }` 這類全域選擇器會連 `<html>` 一起吃到，若 `<html>` 沒有明確 color，會 resolve 成 initial value（通常是黑），子層 `body { color: X }` 沒加 `!important` 就會輸掉這場 specificity/important 之爭而繼續顯示黑字

拿到這三個數值後才能判斷是「media query 沒 match」「body 背景沒套上」還是「中間容器/文字色被吃掉」，三種修法完全不同，混著猜會浪費排查時間。

## 目前使用專案
- Monori（2026-08-20）：用此診斷法確認 5 個 reader 來源（Patreon/AO3/Google Docs/AFF/Vocus）dark mode 問題的真正根因分佈在第 2、3 層，而非最初懷疑的第 1 層（media query）
```
