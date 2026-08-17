# WIKI_SYNC

> 來源 project: monori
> 產出日期: 2026-08-16
> 同步目標: knowledge-wiki/wiki-pages/専案管理/

使用方式：在 knowledge-wiki session 中執行「専案管理 update」，將以下內容分別寫入對應路徑。

---

## patterns/（可複用模式）

**pattern_plan-gives-way-to-review-defects.md 建議內容：**

```
## 問題描述
用「寫計畫 → subagent 逐 task 執行 → review」的流程做開發時，計畫裡寫死的程式碼或測試
本身就帶了缺陷（例如：一個測試在輸入為空時會無條件通過，或會 crash 整個測試 process）。
執行 task 的 subagent 會忠實照抄計畫文字，缺陷跟著原封不動落地；task review 才抓到。
這時「計畫怎麼寫」和「怎麼做才對」互相衝突，執行者不該自己決定該聽誰的。

## 解法
把這類衝突當成一級公民對待，不要讓 subagent 自己判斷：
1. Review 抓到的缺陷，若成因可回溯到計畫文字本身，明確標成「plan-mandated」，
   跟其他「subagent 自己做錯」的 finding 分開處理。
2. 這是人類夥伴的裁決權，不是 controller 自己能拍板的事——停下來問一次：
   「計畫這樣寫，但 review 說有問題，要修 code 讓 plan 讓位，還是照 plan 走？」
3. 得到裁決後，同一輪執行中出現的「同一類」缺陷（例如同一份檔案裡另一個一樣會
   vacuous-pass 或會 crash 的測試），可以援引同一個裁決直接處理，不必每個都重問——
   但要在回報裡明講「這是延伸適用先前的裁決，不是重新徵得同意」，讓人類夥伴有機會喊停。
4. 真正落在新類別的計畫衝突，還是要單獨開一次問題。

## 目前使用專案
- monori（subagent-driven-development 執行 AFF 選擇器修復計畫，2026-08-15：
  三個測試在空陣列時會 vacuous-pass 或 crash 整個 xctest process，均為計畫原始文字，
  經人類夥伴裁決「修掉，計畫讓位」後修正並延伸適用於同檔案內的第二個同類缺陷）
```

---

## errors/（踩過的坑）

**error_try-optional-swallows-compile-failure.md 建議內容：**

```
## 症狀
一段功能原本該做的事（例如廣告封鎖規則）突然不生效，但完全沒有任何錯誤訊息、
log 或崩潰可循——程式碼看起來執行成功了，只是效果消失。

## 根因
`guard let x = try? someThrowingCall() else { return }` 這個寫法把兩種完全不同的
失敗原因（拋出例外、或成功回傳但結果是 nil）都壓縮成同一條靜默的 early return。
`try?` 本身就會把錯誤訊息丟掉，`guard...else { return }` 又不留任何痕跡——
兩者疊加，出問題時除了讀原始碼之外沒有任何辦法知道發生了什麼事。

這個模式特別容易在「解析／編譯一段動態產生的內容」的程式碼裡出現：
內容本身（例如一段 JSON 規則、一段字串樣板）之後被修改，解析／編譯開始失敗，
但呼叫端的錯誤處理從一開始就沒打算處理這個情境。

## 修法
把 `try?` + `guard...else { return }` 換成 `do { ... } catch { log(error) }`，
且兩個失敗分支（拋出的錯誤、與成功但回傳 nil）都要留下診斷紀錄。
成功路徑的行為必須完全不變。

## 預防措施
- 修改「被動態解析/編譯的內容」（規則清單、範本字串、schema）時，
  順手檢查呼叫端的錯誤處理路徑是否會留下痕跡，不要只看 happy path 有沒有跑對。
- Code review 時看到 `try?` 接 `guard...else { return }`，預設當成一個需要說明的
  設計選擇，而不是無害的簡寫。

## 出現過的專案
- monori（2026-08-15，`WKContentRuleListStore.compileContentRuleList` 的呼叫端）
```
