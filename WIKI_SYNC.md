# WIKI_SYNC

> 來源 project: Monori
> 產出日期: 2026-06-20（含 2026-06-19 未同步項目）
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
- Monori（2026-06-19）
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
- Monori（2026-06-19，Bug 4 gray veil debug session）
```

---

**error_ios-launch-storyboard-targetruntime.md 建議內容：**
```
## 症狀
手寫（非 Interface Builder 產出）的 iOS `LaunchScreen.storyboard` 編譯失敗：
`The document "LaunchScreen.storyboard" could not be opened.
(com.apple.InterfaceBuilder error -1.)`
ibtool stack trace 停在 `IBDocument unarchivePlatformIndependentDataWithUnarchiver`。

## 根因
`<document targetRuntime="...">` 寫成 macOS 的值（`AppleCocoa` 或亂猜的
`AppleCocoa.CocoaTouch`）。ibtool 印 `Unknown target runtime "AppleCocoa"` 後即 abort。
iOS storyboard 的正確值是 `iOS.CocoaTouch`。次要陷阱：safe-area layout guide 的
element key 是 `safeArea`，不是 `safeAreaLayoutGuide`。

## 修法
- `targetRuntime="iOS.CocoaTouch"`
- safe area 用 `<viewLayoutGuide key="safeArea" id="..."/>`
- 對照系統樣板（最可靠的格式來源）：
  /Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/
    Project Templates/MultiPlatform/Application/iOS App Base.xctemplate/LaunchScreen.storyboard

## 預防措施
手寫任何 .storyboard/.xib 後，先用
`ibtool --errors --warnings --notices File.storyboard` 驗證（0 error 才算過），
不要等 xcodebuild 才發現。格式從系統樣板複製，不要憑記憶寫 document header。

## 出現過的專案
- Monori（2026-06-20，手寫啟動畫面）
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
- Monori（ReaderStyler.wrappedDocument()，2026-06-19）
```

---

**pattern_bundleid-rename-resets-local-data.md 建議內容：**
```
## 問題描述
iOS app 改 bundle identifier（rebrand / 改名）後，使用者「資料不見了」：
書庫、設定、登入狀態全部重置。誤以為是 migration bug。

## 解法
這不是 bug，是 sandbox 行為——改 bundle id = 系統視為新 app = 全新 container。
規劃改名時要先盤點本機持久層，並把資料重置當作預期結果寫進交接：

1. 盤點儲存載體：
   - `UserDefaults.standard` → 綁 bundle id，會清空
   - 具名 suite / App Group（`group.xxx`）→ 若 group id 不變則保留；改了就清空
   - SwiftData/CoreData 預設 `ModelContainer` → 在 app container 內，清空
   - Keychain → 用 access group；無 group 時綁 bundle id
2. 若資料必須保留 → 需寫一次性遷移（舊→新 App Group），或乾脆不改 bundle id
3. dev / 早期 app → 通常接受重置，交接寫明「使用者需重登 + 重建資料」
4. WKWebView 登入態（cookie/`WKWebsiteDataStore`）綁 app container → 改 id 後需重登

## 排查指令
git grep -nE 'UserDefaults|suiteName|ModelContainer|appGroup|group\.|Keychain'
無 App Group / 無具名 suite = 改 id 後本機資料必然全失。

## 目前使用專案
- Chapterly→Monori（2026-06-20，rebrand 規劃；`dev.chapterly`→`dev.monori`）
```
