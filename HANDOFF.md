# HANDOFF

> 上次 session: 2026-08-15（AsianFanfics 2026 改版適配修復）
> 下次接手請從「接手要做的事」開始

## 狀態
AsianFanfics 於 2026 年出了一次 Tailwind 前端改版（`body.goth-shell`），舊選擇器全滅，任何故事匯入都跳 `未找到章節` / `此頁面未找到章節連結`。已定位根因、改鎖語意化屬性重寫適配器，並在 Simulator 對正式站 end-to-end 驗證通過。
- 測試/建置狀態：✅ 綠（跑 `./scripts/verify.sh` 確認；277 XCTest + 11 swift-testing，0 failures）
- 分支 ＠ 最後 commit：`fix/aff-2026-redesign @ 028ff85`
- 工作樹：clean（`brag-output/`、`skills-staging/` 為未追蹤的暫存目錄，刻意不 commit）

## ✅ 本次完成
- 定位根因：AsianFanfics 改版後 `#story-title`、`.widget--chapters`、`select[name="chapter-nav"]`、`main.primary`、`#user-submitted-body` 全部消失或回 0 nodes。2026-08-15 於正式站 1280px（桌機）/375px（手機）、登出狀態驗證，並用另一篇不同作者的故事（`/story/view/1470000`）交叉確認為全站性，非單篇或單版型問題
- 章節清單改鎖 `data-toc-chapter`：TOC 桌機 `aside` + 手機 `dialog` 各渲染一份，依章節編號去重；`0` = Foreword 視為 metadata、非章節；client 插入的「▶ Continue」列沒有 `data-toc-chapter`，天然被排除
- 故事標題／作者改抓「第一個含 `<h1>` 的 `<header>`」
- 章節網址加上 slug 段（如 `/story/view/1754805/3/paper-ghosts-ipsum`）的正規化涵蓋
- Reader 樣式表改鎖定 `#bodyText`，並收斂 `aside` 隱藏規則的作用範圍
- Browse 模式下隱藏改版新增的廣告／推廣版位
- 9 個 commit（`07e5034`…`028ff85`，逐一列表見 ADR-0009）＋ ADR-0009 記錄決策、證據與接受的風險
- 驗證：`./scripts/verify.sh` 綠燈（`** BUILD SUCCEEDED **`，277 XCTest + 11 swift-testing，0 failures）；iOS Simulator 對正式站 end-to-end 驗證：banner 顯示真實標題「Paper Ghosts (Ipsum)」、匯入回報「已匯入 5 個章節」、書庫依序列出 Chapter 1-5（無 Foreword、無 Continue 列）、Chapter 2 開啟後為乾淨文字、無網站 nav/footer/浮動底部列/廣告。截圖：`build/smoke/ui/step-245-11-import-tapped.png`、`step-248-14-toc-open.png`、`step-249-15-chapter2-reader.png`
- 已知瑕疵（非本次修復範圍，記在 ADR-0009 Consequences）：reader 背景色是 AFF 自己的深藍（wrapper 的 `dark:bg-[#0f172a]`）而非 ruleset 的 `#1c1b19`，因為 `AFFReaderRuleset.css` 只畫 `body`，wrapper 蓋在上面；文字仍可讀，未修

## 🔄 進行中
- **Google Docs 登入彈出視窗導覽 bug（獨立問題，尚未修復）**：密碼＋2FA 通過後，Drive 會在手機瀏覽器開啟，app 端卡在空白頁。這是與本次 AFF 修復無關的獨立調查，計畫在 `docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`。**根因尚未確認**，不要當成已修好或已診斷。

## 🚧 試過但行不通（避免重踩）
- **不要靠加碼偽裝去對抗 Google 的再次封鎖**：UA 標示為 Safari 只是暫時有效。Google 的 embedded webview 檢查是防釣魚保護，針對的正是會對頁面注入 JS 的 app，Monori 確實會注入。再壞時改走引導使用者的路（見 ADR-0008）
- **只改 `App/Info.plist` 的版本號沒用**：xcodegen 會重新產生該檔並重設為 1.0 / 1，必須改 `project.yml` 的 `info.properties`
- **`swift test` 報 `build.db: disk I/O error`**：跑 `swift package clean` 修復（xcodebuild 的 SWBBuildService 佔用）
- **AFF 選擇器綁 Tailwind utility class 會再壞**：這次全滅的 `#story-title`／`.widget--chapters`／`select[name="chapter-nav"]`／`main.primary`／`#user-submitted-body` 就是教訓。下次改動或新增 AFF 選擇器，改鎖語意化的 `data-toc-*` 屬性（或等同穩定 hook），不要綁 `span.truncate` 這類會隨改版重生成的 class（見 ADR-0009）

## ⚡ 接手要做的事
1. **AFF 沒有待辦**：本次修復已在正式站 end-to-end 驗證通過，不需複測。若 AFF 未來又改版，先用瀏覽器對正式站即時 DOM 重新檢查（如這次的 1280px/375px、登出流程），不要沿用舊選擇器假設
2. **Google Docs 登入彈出視窗導覽 bug**：獨立問題，計畫見 `docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`；根因尚未確認，下一步是照計畫診斷，不要直接套用 AFF 或 Patreon 登入的既有假設
3. **這個分支要收尾**：目前在 `fix/aff-2026-redesign @ 028ff85`（加上本次的 docs commit）。決定 merge/PR 流程時可參考 `superpowers:finishing-a-development-branch`

## ⚠️ 注意事項
- 真實 Patreon 登入沒有跑過。本次只驗到「SDK 載入成功、授權頁開得出來」，整條登入走完會不會拿到 session 尚未證實 —— 那是手動使用者步驟
- Patreon 換 UA 後餵的是完整版登入頁，排版與舊的降級版不同。任何依賴登入頁 DOM 的東西要重對
- Facebook 白名單用 suffix match，副作用是 Patreon 貼文裡的 facebook 連結也會留在 app 內而不是開 Safari（刻意取捨）
- 測試用的模擬器是 iPhone 17 Pro Max（已關機），上面裝了 Debug build 但沒有 Patreon 登入狀態；使用者原本 iPhone 17 Pro 上那份沒有被動到

## 📁 本次修改的檔案
- `MonoriCore/Sources/MonoriCore/Assets/AFFStoryImport.js` — 章節清單改鎖 `data-toc-chapter`（去重、排除 Foreword/Continue 列）、標題/作者改抓含 `<h1>` 的 `<header>`
- `MonoriCore/Sources/MonoriCore/Assets/AFFStoryDetect.js` — 配合改版後的頁面結構調整偵測邏輯
- `MonoriCore/Sources/MonoriCore/Assets/AFFReaderRuleset.css` — 樣式表改鎖定 `#bodyText`，收斂 `aside` 隱藏規則的作用範圍
- `MonoriCore/Sources/MonoriCore/Assets/AFFBrowseRuleset.css` — 隱藏改版新增的廣告／推廣版位
- `App/WebView/WebViewModel.swift` — content rule list 選擇器換成改版後的廣告/推廣版位（`ins.adsbygoogle`、`#story-promote`、`#story-feed` 等）
- `MonoriCore/Tests/MonoriCoreTests/AFFExtractionTests.swift` — 新增，改版 fixture 的章節/標題/作者抽取測試
- `MonoriCore/Tests/MonoriCoreTests/URLNormalizerAFFTests.swift` — 新增，slug 後綴章節網址（`/story/view/1754805/3/paper-ghosts-ipsum`）正規化測試
- `MonoriCore/Tests/MonoriCoreTests/Fixtures/aff-story-foreword.html`、`aff-story-foreword-no-toc.html` — 新增，改版頁面的縮版 fixture
- `docs/decisions/0009-asianfanfics-2026-redesign-selectors.md` — 新增
- `HANDOFF.md`、`MEMORY.md` — 本次記錄

## 🔗 相關資源
- ADR-0009（本次）：`docs/decisions/0009-asianfanfics-2026-redesign-selectors.md`
- ADR-0008（Safari UA）：`docs/decisions/0008-identify-as-safari-in-user-agent.md`
- ADR-0007（popup 只給 OAuth）：`docs/decisions/0007-popup-windows-only-for-oauth.md`
- Google Docs 登入彈出視窗導覽 bug 的計畫：`docs/superpowers/plans/2026-08-15-google-login-popup-navigation.md`
- App Store Connect app id：`6799533673`
- 重現 Patreon Google 403 的最短指令：`curl -A "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" -o /dev/null -w "%{http_code}\n" https://accounts.google.com/gsi/client`
