# Monori 合規說明

## Monori 是什麼

Monori 是 local-first 的 iOS 閱讀 App，讀的是使用者原本就能透過所支援網站存取的內容，目前支援 Patreon、Google Docs、AO3（Archive of Our Own）、方格子（Vocus）、AsianFanfics、CXC、slashtw（在水裡寫字）七個來源。

App 沒有 Monori 自己的後端、帳號系統、分析服務、廣告服務，也沒有跨使用者的內容服務。網站內容一律透過 `WKWebView` 存取；部分支援匯入的來源，會用 WebView 裡已經登入的 session 直接發 request 取得內容。

Monori 不提供另外的內容託管服務，也不會把各平台的流量轉一手經過 Monori 的伺服器。

## 各來源的行為

### Patreon

- 使用者在 App 的 WebView 裡登入自己的 Patreon 帳號。
- 頁面由 Patreon 自己提供，認證與存取控制也由 Patreon 自己把關。
- Monori 不使用 Patreon 的官方或內部 API。
- Collection 匯入器讀的是 WebView 裡已經顯示出來的 Patreon 頁面上的章節連結與 metadata。
- Patreon 貼文內容透過 WebView 讀取，不會下載到 Monori 的伺服器（因為沒有這個伺服器）。
- 閱讀進度、書籤、collection metadata、章節連結存在裝置本機。
- Monori 不提供 Patreon 貼文的離線副本。

### Google Docs

- 使用者用自己的 Google 帳號在 WebView 裡開啟 Google Docs／Drive。
- 使用者明確按下匯入時，匯入器會用當下已登入的頁面 context 去要文件的 `/mobilebasic` HTML。
- 匯入的文件 HTML 可能會存在本機的 library 裡，這樣 Reader 之後不用保留原本的頁面就能顯示內容。
- 文件不會上傳到 Monori 的伺服器，因為這個伺服器不存在。
- Monori 不會取得或匯出 Google 帳號的 cookie 給任何外部服務。

### AO3

- 使用者透過 WebView 存取 AO3。
- 需要登入才看得到的章節與導覽頁面，用 WebView 現有的 session 去要。
- 匯入的章節 HTML 可能會存在本機 library 裡。
- Monori 不會把 AO3 內容上傳到自己的伺服器，也不提供跨使用者的內容庫。
- Monori 不把 AO3 API 當成後端服務使用。

### 方格子

- 使用者透過 WebView 存取方格子。
- Monori 從 WebView 目前載入的頁面判斷是不是支援的方格子沙龍／文章頁面，導覽時用網站自己的網址。
- 在有對應匯入器提供 HTML 內容時，匯入內容可能會存在本機 library 裡。
- 不會把方格子的內容送到 Monori 的伺服器。
- Monori 不維運方格子內容的鏡像或共用庫。

### AsianFanfics

- 使用者透過 WebView 存取 AsianFanfics。
- 支援的故事頁面會被偵測出來，透過 App 的閱讀介面顯示。
- App 對 AsianFanfics 頁面上支援的廣告與追蹤資源套用本機的封鎖規則。這些規則在 WebKit 本機執行，不會把流量繞經 Monori 的伺服器。
- 在有對應匯入器提供 HTML 內容時，匯入內容可能會存在本機 library 裡。
- 不會把 AsianFanfics 的內容送到 Monori 的伺服器。

### CXC

- 使用者透過 WebView 存取 CXC。
- Monori 從 WebView 目前載入的頁面判斷是否為支援的作品頁，導覽時用網站自己的網址。
- 匯入器讀取的是章節標題與網址等 metadata，存在本機 library 裡；不擷取、不儲存章節內文 HTML，也不提供 CXC 作品內容的離線副本。
- Monori 不做後端 proxy，不會把 CXC 的內容送到 Monori 的伺服器。
- Monori 不使用 CXC 的官方或內部 API。

### slashtw

- 使用者透過 WebView 存取 slashtw。
- Monori 從 WebView 目前載入的頁面判斷是否為支援的帖子頁，導覽時用網站自己的網址。
- 匯入器讀取的是章節標題與網址等 metadata，存在本機 library 裡；不擷取、不儲存帖子內文 HTML，也不提供 slashtw 帖子內容的離線副本。
- Monori 不做後端 proxy，不會把 slashtw 的內容送到 Monori 的伺服器。
- Monori 不使用 slashtw 的官方或內部 API。
- slashtw 沒有公開的使用者條款；Monori 採取保守策略，僅以 Web-based 方式呈現內容，不做額外的本地內容擷取或儲存。

## 認證與網站資料

- Monori 不會列舉、複製、匯出認證用的 cookie 給自己的服務使用。
- `WKWebView` 負責管理各平台的網站資料與認證 session。
- App 可以在登出時清除 WebView 的網站資料。
- 每個平台自己負責認證與存取控制，Monori 不試圖繞過這些控制。

## 網路架構

Monori 沒有後端 proxy。WebView 發出的請求會直接打到平台本身，或平台頁面裡參照的資源，Monori 不會把自己的伺服器插在使用者和平台之間。

部分匯入器會用頁面 context 發出已認證的請求來取得內容給本機 Reader 用，這些請求用的是既有的 WebView session，不會經過 Monori 後端。

使用者把 collection 標成「追更中」後，App 會在前景對該 collection 做週期性的檢查請求，走的一樣是既有的 WebView session，不經過 Monori 伺服器。目前只有 Patreon 支援自動檢查，其他來源仍然是手動按「檢查新章節」。

Monori 不攔截 WebView 任意的網路回應。

iCloud 備份與還原時，App 透過 CloudKit 框架與使用者自己的 iCloud 帳號通訊。這些請求由 CloudKit 直接處理，不經過 Monori 的伺服器。

## iCloud 備份

Monori 提供手動的 iCloud 備份與還原功能。

備份的內容：

- Collection 與章節 metadata（標題、網址、來源、排序）。
- 書籤與閱讀進度。
- 閱歷（章節開啟紀錄）。

不備份的內容：

- 匯入的文章 HTML。
- 認證 cookie、session、token。
- 使用者的帳號憑證。
- 閱讀偏好設定（字型大小、主題）。

備份使用使用者自己的 iCloud 帳號，透過 CloudKit 的 private database 存取。每次備份是完整快照，不是差量同步。備份資料只有使用者自己的 iCloud 帳號可以存取。

Monori 不做自動同步、不做跨裝置即時同步、不把備份資料送到 Monori 的伺服器。

## Monori 不提供的東西

- 沒有 Monori 後端。iCloud 備份使用使用者自己的 iCloud 帳號，不經過 Monori 的伺服器。
- 不提供跨使用者的內容分享或彙整。
- 不會把匯入的章節／文件內容上傳到 Monori 的基礎設施。
- 沒有內容分析、廣告分析，也沒有 AI 服務會收到匯入的內容。
- 沒有匯入內容的匯出功能。
- Monori 不管理任何平台的 API 憑證。
- 沒有任何機制是設計來繞過平台的認證或會員／存取控制。

## 本機儲存的內容

依來源與匯入方式不同，本機的 SwiftData library 可能會存：

- Collection 與章節標題。
- 來源網址與章節網址。
- 創作者名稱、看得到的日期字串。
- 閱讀狀態、排序、閱讀進度、書籤。
- 字型與閱讀偏好設定。
- 閱歷（章節開啟紀錄與時間戳記）。
- 需要本機內容才能顯示的來源，其匯入的章節／文件 HTML。

這些都是本機 App 資料。iCloud 備份會備份上述除了文章 HTML 與偏好設定以外的 metadata，但備份資料存在使用者自己的 iCloud 帳號裡，不經過 Monori 的伺服器。

## 資料刪除

- **清除 Library 資料**：刪除本機 library 的 metadata、閱歷與 App 存下的匯入內容。iCloud 備份不受影響。
- **登出**：可以清除 WebView 的網站資料，結束對應網站的 session。
- **從 iCloud 還原**：以 iCloud 備份覆蓋本機書庫。還原前會先快照本機資料，還原失敗時自動 rollback。
- 刪除 App 本身，本機資料會依 iOS 的資料管理機制一併移除。iCloud 備份會保留在使用者的 iCloud 帳號中。

## 存取權收回

用 WebView 閱讀的來源，平台本身才是存取權的最終依據。存取權被收回時，Monori 沒有 Monori 端存的副本可以拿來還原存取。

有支援本機匯入的來源，先前匯入的內容可能會留在裝置的本機 library，直到使用者自己刪除。平台端收回存取權，不代表使用者先前自己選擇匯入到本機的副本會被自動清掉，Monori 不做這個保證。

## App Store 與平台政策風險

Monori 目前規劃透過 App Store 發布。App Store 審查跟上面講的技術網路架構是兩回事。

Apple 的審查規則要求「主要提供網頁內容」的 App 要有足夠的 App 專屬功能。因此 Monori 在 WebView 呈現之外，還仰賴原生的 library 管理、閱讀進度、書籤、章節導覽、閱讀偏好設定、來源處理與匯入流程。這些功能是否滿足 App Store 審查標準，是 Apple 審查的判斷，這份文件沒辦法保證結果。

## 平台條款與政策風險

Monori 的技術行為本身，不代表每個支援的平台都認可這些使用方式。各平台的服務條款、使用規範、著作權政策、認證規則，以及網站行為的變動，都可能帶來額外限制。

目前這個專案把這件事當成政策／合規風險處理，不主張各平台明確認可 Monori。專案不主張跟 Patreon、Google、AO3、方格子、AsianFanfics、CXC、slashtw 有任何關係。

支援的平台隨時可能改版面、認證流程、防爬蟲機制、API 或條款。這類變動可能讓某個匯入器失效，或讓某個功能暫時用不了，但不會改變 App 本機為主的網路架構。

## 工程紅線

以下是刻意設下的邊界，沒有經過額外的合規審查，不能拿掉：

- 不做後端或內容 proxy。
- 不擷取 cookie，不匯出憑證。
- App 裡不放任何平台的 API 金鑰或私有憑證。
- 不做跨使用者的內容服務。
- 不把匯入的內容上傳給第三方分析、AI 或儲存服務。
- 不做任何以繞過平台存取控制為目的的功能。
- 不把文章內容備份到 iCloud。
