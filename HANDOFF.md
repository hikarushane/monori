# HANDOFF

> 上次 session: 2026-08-16（AsianFanfics 2026 改版修復並 merge；Google Docs 登入問題已根因調查、計畫待執行）
> 下次接手請從「接手要做的事」開始

## 狀態
AsianFanfics 匯入/偵測/閱讀器/廣告封鎖已全數修復並 merge 進 main。Google Docs 登入空白畫面是獨立問題，已完成根因初步調查與寫計畫，尚未執行任何 task。
- 測試/建置狀態：✅ 綠（跑 `./scripts/verify.sh` 確認；`** BUILD SUCCEEDED **`，279 XCTest + 11 swift-testing，0 failures）
- 分支 ＠ 最後 commit：`main @ e1b3ee1`（本地領先遠端 `main/main` 16 個 commit，尚未 push）
- 工作樹：clean（`brag-output/`、`skills-staging/` 為未追蹤暫存目錄，非本次產物）

## ✅ 本次完成
- 根因確認：AsianFanfics 全站改版 Tailwind（`body.goth-shell`），舊選擇器 `#story-title`、`.widget--chapters`、`select[name="chapter-nav"]`、`main.primary`、`#user-submitted-body` 全部消失或回 0 nodes，任何故事匯入都跳「未找到章節」。於正式站桌機 1280px／手機 375px、登出狀態驗證為全站性，並用另一位作者的故事交叉確認
- 用 subagent-driven-development 執行 8-task 計畫（`docs/superpowers/plans/2026-08-15-aff-redesign-adapter.md`）：
  - `AFFStoryImport.js` 改鎖 `data-toc-chapter`，去重桌機/手機雙份 TOC、跳過 Foreword（`data-toc-chapter="0"`）與「▶ Continue」列，補連結掃描 fallback
  - `AFFStoryDetect.js` 改抓第一個含 `<h1>` 的 `<header>`
  - `AFFReaderRuleset.css` 白名單改鎖 `#bodyText` / `section#comments`
  - `AFFBrowseRuleset.css` + `affAdBlockRules` 廣告選擇器改新版（`ins.adsbygoogle`、`#story-promote`、`#story-feed`）
- 每個 task 皆過 spec + quality review；兩輪 fix loop 修掉計畫文字本身寫錯的測試（空跑通過、`chapters[0]` 會 crash 整個 test binary）
- 全分支最終 review（opus）再抓 3 個 Important，一輪修正：CSS 樣式表補上自動測試覆蓋（含「先讓測試紅過」的證據）、`WKContentRuleListStore` 編譯失敗補上 `DiagnosticLog`（原本 `try?` 靜默吞掉）、fixture 擴到 12 章釘住數字排序（非字串排序）
- Simulator 對正式站端到端驗證：真標題橫幅、匯入回報「已匯入 5 個章節」、書庫五章順序正確無 Foreword、Chapter 2 閱讀器乾淨無站方 nav/footer/廣告；使用者手動確認留言串在正式站正常顯示
- Fast-forward merge 進 main，刪除分支 `fix/aff-2026-redesign`，清除 SDD 工作區
- 寫 ADR-0009 記錄改版證據與新選擇器契約；更新 MEMORY.md、WIKI_SYNC.md

## 🔄 進行中
- **Google Docs 登入後開出手機瀏覽器、app 內留空白畫面**
  - 做到：計畫已寫好（`docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`），確認一個真實缺陷 —— `App/WebView/WebViewModel.swift` 建立 OAuth popup 時只設了 `uiDelegate`、沒設 `navigationDelegate`，popup 內每次導覽都繞過 `NavigationPolicy`（包括 Google Drive 需要的 Universal-Link 抑制）。但這是不是這次症狀的根因，還沒有證據
  - 未完成：0 個 task 執行。Task 1（不含 token 的導覽追蹤儀器化）agent 可獨立完成；Task 2 是證據閘門，需要使用者輸入密碼與 2FA、agent 同步抓 log 判斷 popup 是否為因，才決定 Task 4/5 怎麼修
  - 完成判準：Google 帳號密碼＋2FA 後，Google Drive 開在 app 內、Safari 不會前景、不留空白 sheet；`build/nav-trace.log` 沒有任何 Google host 的 `-> openInSafari`

## 🚧 試過但行不通（避免重踩）
- 本次無。AFF 修復過程中 review 抓到的測試缺陷（空跑通過、crash-prone subscript、unscoped `aside` 規則）都是計畫文字本身寫錯，屬於「計畫讓位」修正，不是嘗試失敗

## ⚡ 接手要做的事
1. 跑 Google 登入計畫 Task 1（追蹤儀器化，不需使用者介入）
2. 找時間跑 Task 2：使用者輸入密碼＋2FA，agent 同步抓 log，判斷 popup 缺陷是否為根因
3. （可選）`git push main main:main` 把本地領先的 16 個 commit 推上去——使用者尚未要求

## ⚠️ 注意事項
- **兩份計畫檔案不在 git 版控裡**：`docs/superpowers/plans/2026-08-15-aff-redesign-adapter.md` 與 `2026-08-15-google-login-popup-navigation.md` 因 `.gitignore` 的 `docs/superpowers/` 規則被排除（`git status --ignored` 可見），只存在這台機器的工作目錄。換機器或重新 clone 會消失，Google 登入計畫尚未執行，遺失前建議先手動備份或另外 commit
- 遠端名稱是 `main` 不是 `origin`（git 會印 `refname 'main' is ambiguous` 警告）。指令中裸寫 `main` 會混淆本地分支與遠端，一律用 `refs/heads/main` 或 `main/main` 明確指定
- AFF 選擇器改動前務必先對正式站即時 DOM 重新驗證，不能只憑 ADR-0009 或 MEMORY.md 的紀錄——AFF 一改版視覺，Tailwind utility class 就會整批重生成

## 📁 本次修改的檔案
- `MonoriCore/Sources/MonoriCore/Assets/AFFStoryImport.js` — 改用 `data-toc-chapter` 掃描 + 連結掃描 fallback
- `MonoriCore/Sources/MonoriCore/Assets/AFFStoryDetect.js` — 改抓含 `<h1>` 的 `<header>`
- `MonoriCore/Sources/MonoriCore/Assets/AFFReaderRuleset.css` — 白名單改鎖 `#bodyText`
- `MonoriCore/Sources/MonoriCore/Assets/AFFBrowseRuleset.css` — 廣告選擇器改新版
- `App/WebView/WebViewModel.swift` — `affAdBlockRules` 選擇器更新；`installAFFAdBlockRules` 編譯失敗補 log
- `MonoriCore/Tests/MonoriCoreTests/AFFExtractionTests.swift`（新增，含樣式表覆蓋）、`URLNormalizerAFFTests.swift`、兩個新 fixture（其一擴到 12 章）
- `docs/decisions/0009-asianfanfics-2026-redesign-selectors.md`（新增）
- `MEMORY.md`、`WIKI_SYNC.md`

## 🔗 相關資源
- AFF 修復計畫：`docs/superpowers/plans/2026-08-15-aff-redesign-adapter.md`（未追蹤於 git）
- Google 登入計畫：`docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`（未追蹤於 git）
- ADR-0009：`docs/decisions/0009-asianfanfics-2026-redesign-selectors.md`
