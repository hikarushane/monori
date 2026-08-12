# HANDOFF

> 上次 session: 2026-08-12（Patreon Google 登入根因調查與修復 + TestFlight build 3）
> 下次接手請從「接手要做的事」開始

## 狀態
內測人員回報的 Patreon Google 登入失效已找到根因並修好，Facebook 登入的獨立 bug 一併修掉。
- 測試/建置狀態：✅ 綠（跑 `./scripts/verify.sh` 確認；265 XCTest + 11 swift-testing，0 failures）
- 分支 ＠ 最後 commit：`main @ e9b2235`
- 工作樹：clean（`.asc/`、`brag-output/`、`skills-staging/` 為未追蹤的暫存目錄，刻意不 commit）

## ✅ 本次完成
- 定位根因：WKWebView 預設 UA 沒有 `Version/` 與 `Safari/` token → Google 對 `accounts.google.com/gsi/client` 回 403 → Patreon 的 Google 按鈕拿不到 SDK 而停用
- `BrowserIdentity.userAgentSuffix` + `applicationNameForUserAgent`，WebView 對外呈現為 Safari
- `NavigationPolicy` 補上 Facebook OAuth 主機（decide 用 suffix、popup 判定用精確比對）
- 新增 `BrowserIdentityTests`、`NavigationPolicyFacebookTests`（先紅後綠）
- ADR-0008 記錄決策、證據與接受的風險；README 已知限制補上失效症狀與繞道
- MEMORY.md 補三筆坑與兩筆架構決策
- build number 提升到 3（釘在 `project.yml`）

## 🔄 進行中
- **TestFlight build 3 上傳**
  - 做到：程式碼已 commit，build number 已 bump 到 3
  - 未完成：archive → export → upload
  - 阻塞：帳號只有 DEVELOPMENT 憑證，沒有 Apple Distribution 憑證（`asc certificates list` 只回一筆 DEVELOPMENT；keychain 也查不到 Apple Distribution）。build 1、2 應該是從 Xcode 用 cloud-managed signing 上傳的
  - 完成判準：`asc builds list --app 6799533673` 看得到 version 3 且 processingState 為 VALID，並已指派給測試群組

## 🚧 試過但行不通（避免重踩）
- **不要靠加碼偽裝去對抗 Google 的再次封鎖**：UA 標示為 Safari 只是暫時有效。Google 的 embedded webview 檢查是防釣魚保護，針對的正是會對頁面注入 JS 的 app，Monori 確實會注入。再壞時改走引導使用者的路（見 ADR-0008）
- **只改 `App/Info.plist` 的版本號沒用**：xcodegen 會重新產生該檔並重設為 1.0 / 1，必須改 `project.yml` 的 `info.properties`
- **`swift test` 報 `build.db: disk I/O error`**：跑 `swift package clean` 修復（xcodebuild 的 SWBBuildService 佔用）

## ⚡ 接手要做的事
1. **解掉 TestFlight 上傳的簽章阻塞**：最省事的路是使用者在 Xcode 開 `Monori.xcodeproj` → Product → Archive → Distribute App → TestFlight，讓 Xcode 自動建立 distribution 憑證。若要留在 CLI，需要先有 Apple Distribution 憑證，指令是 `asc xcode archive --project Monori.xcodeproj --scheme Monori --configuration Release --archive-path .asc/artifacts/Monori.xcarchive` 再 `asc xcode export` → `asc publish testflight --app 6799533673 --ipa <path> --group <group-id>`
2. **決定發給哪個群組**：`Monori 內測`（internal，`285e0421-0ff0-4036-b4a5-8f23ee73703e`，立即發布）或 `monori 外測`（external，`9992ed2f-e7dc-4b58-8fc0-e798137fecf0`，需 Beta App Review）
3. **請回報的內測人員複測**：登入頁應該長成 SSO 三顆在上、email 欄在下、底下有「需要登入方面的協助？」；Google 按鈕點下去會開出 app 內的 Google 授權頁

## ⚠️ 注意事項
- 真實 Patreon 登入沒有跑過。本次只驗到「SDK 載入成功、授權頁開得出來」，整條登入走完會不會拿到 session 尚未證實 —— 那是手動使用者步驟
- Patreon 換 UA 後餵的是完整版登入頁，排版與舊的降級版不同。任何依賴登入頁 DOM 的東西要重對
- Facebook 白名單用 suffix match，副作用是 Patreon 貼文裡的 facebook 連結也會留在 app 內而不是開 Safari（刻意取捨）
- 測試用的模擬器是 iPhone 17 Pro Max（已關機），上面裝了 Debug build 但沒有 Patreon 登入狀態；使用者原本 iPhone 17 Pro 上那份沒有被動到

## 📁 本次修改的檔案
- `MonoriCore/Sources/MonoriCore/BrowserIdentity.swift` — 新增，UA 後綴常數
- `App/WebView/WebViewModel.swift` — 設 `applicationNameForUserAgent`
- `MonoriCore/Sources/MonoriCore/NavigationPolicy.swift` — Facebook 主機進兩份白名單
- `MonoriCore/Tests/MonoriCoreTests/BrowserIdentityTests.swift` — 新增
- `MonoriCore/Tests/MonoriCoreTests/NavigationPolicyFacebookTests.swift` — 新增
- `docs/decisions/0008-identify-as-safari-in-user-agent.md` — 新增
- `README.md` — 已知限制 + 修正 SSO 敘述
- `MEMORY.md` — 三筆坑、兩筆架構決策、兩筆待辦
- `project.yml`、`App/Info.plist` — build number 3

## 🔗 相關資源
- ADR-0008：`docs/decisions/0008-identify-as-safari-in-user-agent.md`
- ADR-0007（popup 只給 OAuth）：`docs/decisions/0007-popup-windows-only-for-oauth.md`
- App Store Connect app id：`6799533673`
- 重現 403 的最短指令：`curl -A "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" -o /dev/null -w "%{http_code}\n" https://accounts.google.com/gsi/client`
