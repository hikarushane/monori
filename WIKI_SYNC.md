# WIKI_SYNC

> 來源 project: Chapterly
> 產出日期: 2026-06-11
> 同步目標: knowledge-wiki/wiki-pages/専案管理/

使用方式：在 knowledge-wiki session 中執行「専案管理 update」，將以下內容分別寫入對應路徑。

---

## patterns/（可複用模式）

**pattern_swiftui_color_clear_spacer.md 建議內容：**
```
## 問題描述
SwiftUI VStack 中用 `Color.clear.frame(width: N)` 做佔位元件，沒有指定 `height:`，
導致 VStack 把剩餘垂直空間全給它，元件膨脹到佔滿畫面。

## 解法
永遠同時指定 width 和 height：
```swift
Color.clear.frame(width: 72, height: 0)
```
`height: 0` 明確告訴 SwiftUI 不需要垂直空間。

## 適用場景
任何需要「佔住水平寬度但不佔高度」的 SwiftUI 佔位，例如：
- 導覽列左右對稱用的空白格
- 按鈕位置佔位（當按鈕條件顯示時）

## 出現過的專案
- Chapterly（2026-06-11）：Reader 底部 Prev/Next 按鈕佔位
```

---

**pattern_wkwebview_spa_dom_polling.md 建議內容：**
```
## 問題描述
WKWebView 中的 SPA（例如 Patreon）用 pushState 切換頁面，
不會觸發 `webView(_:didFinish:)`。URL 改變後，DOM 可能短暫殘留上一頁內容，
直接讀 `document.title` 或 DOM 節點會得到舊值。

## 解法
1. 用 `WKNavigationDelegate.webView(_:didCommit:)` 或 `KVO` 監聽 `url` 屬性偵測 URL 變化
2. URL 變化時立即顯示 slug 作為暫時標題（fallback）
3. 啟動 polling：每 500ms 讀一次 DOM title，最多 N 次（例如 8 次 = 4 秒）
4. Reject 與上一頁相同的標題（避免殘留值被接受）
5. 拿到新標題後停止 polling

## 範例（Swift + async/await）
```swift
func pollForeignTitle(rejecting oldTitle: String) {
    foreignTitleTask?.cancel()
    foreignTitleTask = Task {
        for _ in 0..<8 {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let t = await webView.evaluateJavaScript("document.title") as? String ?? ""
            if !t.isEmpty && t != oldTitle {
                await MainActor.run { foreignPageTitle = t }
                return
            }
        }
    }
}
```

## 注意
- Polling 次數根據頁面複雜度調整；Patreon 用 8×500ms 足夠
- 切換到新文章時先 cancel 舊 task，避免 race condition
- 若頁面已在 Library，可直接用 chapter.title，不需 polling

## 出現過的專案
- Chapterly（2026-06-11）：Reader 導航到未 import 的 related post
```
