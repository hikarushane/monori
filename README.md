# Monori

一個安靜、local-only 的閱讀殼層，讀你自己在 Patreon、Google Docs、AO3、方格子、AsianFanfics 上有權限看的內容。用自己的帳號登入來源網站，把系列的章節匯入 App，用乾淨的排版閱讀，支援上一章／下一章導覽，每章可以個別加書籤。

Monori 不是任何平台的 client 或 API consumer。不繞過存取控制，不把內容存到自己的伺服器，因為根本沒有這個伺服器。細節見 [COMPLIANCE.md](COMPLIANCE.md)。

## 需求

- Xcode 15.4+（iOS 17 SDK）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- 一支 iPhone（側載）或 iOS 模擬器

## Build

```bash
git clone <this repo>
cd Monori
xcodegen generate
open Monori.xcodeproj
```

選 Monori scheme，在 Signing & Capabilities 設定自己的 signing team，在裝置或模擬器上執行。

## 測試

```bash
swift test --package-path MonoriCore
```

## 給非開發者的側載方式

以下任一種：用 build 出來的 `.ipa` 搭配 AltStore／SideStore、用 Xcode 的免費 Apple 開發者憑證（7 天要重簽一次）、或用 Apple Developer Program 會員資格（憑證效期一年）。每個使用者自己簽署 App，用自己的帳號登入各平台。

## 使用方式

1. **Browse** 分頁上方是來源選單，點開可以切換 Patreon、Google Docs、AO3、方格子、AsianFanfics。每個來源各自獨立的 WebView 與登入狀態，互不影響，切換來源不會弄丟其他來源的瀏覽紀錄。在對應平台頁面用自己的帳號登入（Patreon 的 Google、Apple、Facebook 登入都在 app 內的彈出視窗完成）。
2. 匯入依來源而定，頁面上方會出現對應的匯入 banner：
   - **Patreon**：打開系列裡的一篇貼文，出現「系列：⋯」banner 時點**開啟收藏**，到收藏頁面後點**匯入**（章節目錄會自動捲動載入，重複匯入不會產生重複章節）。
   - **AO3**：打開作品頁面，banner 直接顯示**匯入**，點下去匯入整部作品的章節。
   - **方格子**：打開房間頁面，banner 顯示**匯入**，點下去匯入房間裡的文章。
   - **AsianFanfics**：打開故事頁面，banner 顯示**匯入**，點下去匯入故事章節。
   - **Google Docs**：打開文件，banner 顯示「Google 文件」與**匯入**，點下去把內容收進 library；同一份文件裡有多章時，會依標題樣式自動切開。
3. **Library** 分頁選 collection，點章節開始讀。標成**追更中**的 collection 會在前景自動檢查新章節（Settings 可切換；目前僅 Patreon 支援自動檢查，其他來源用手動**檢查新章節**），新章節會有未讀標記，目錄裡也有紅點。工具列選單可以排序（標題／最近更新／最近閱讀）、搜尋標題或作者、依閱讀狀態篩選；下拉可以重新整理所有追更中的 collection。單一 collection 點 **•••** 可以設定閱讀狀態，或手動**檢查新章節**。
4. Reader：預設隱藏工具列，點畫面中間顯示／隱藏。書籤在左上角；字級與行距在偏好設定面板（右上角 ⊤T 按鈕）。左邊緣滑動離開。上一章／下一章在底部工具列。

## 已知限制

- 各平台改版面可能讓 Reader 樣式或匯入功能失效，兩者都會優雅降級（Reader 退回原始頁面；章節目錄可以從 Browse 分頁重新匯入）。
- 沒有離線閱讀，這是刻意的設計。
- **Patreon 的 Google 登入隨時可能再次失效。** 這顆按鈕依賴 Google 的 Identity Services SDK，而 Google 會對它判定為 app 內建瀏覽器的環境回 403。Monori 把 WebView 的 User-Agent 標示為 Safari 讓 SDK 正常載入（見 [ADR-0008](docs/decisions/0008-identify-as-safari-in-user-agent.md)），但 Google 可以隨時加上 User-Agent 以外的判斷。失效時的症狀是「以 Google 繼續登入」變成灰色、按不動。遇到這個狀況：先在 Safari 用 Google 登入 Patreon、到帳號設定加一組密碼，再回 Monori 用 email 加密碼登入；或改用 Apple、Facebook 登入。

## 不要實作的東西

擷取 cookie、攔截網路封包、呼叫平台的官方或內部 API、把內容存到 Monori 自己的伺服器或做匯出、跨使用者分享，細節見 [COMPLIANCE.md](COMPLIANCE.md)。加這些功能的 PR 會被拒絕。
