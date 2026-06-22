# Monori 品牌套用評估報告

> 日期：2026-06-20
> 範圍：把 Google Stitch 產出的 app icon + 標準字（wordmark）+ 配色，套用到目前的 iOS app（Chapterly → Monori）。
> 狀態：**評估報告，尚未改任何 code。** 用 redesign-skill 的設計稽核標準，對應到 iOS / SwiftUI 的實際做法。
>
> **決策已定（2026-06-20）：** ① 互動強調色 = `#5C7150` 深森綠 ② 標準字 = 幾何免費字體（待從樣張挑一支）③ 改名 = Chapterly→Monori **連 bundle id 全改**（需重登 Patreon）。

---

## 0. 設計判讀（Design Read）

把這個品牌讀成：**一款「安靜、閱讀導向」的 iOS app**，視覺語言是「鼠尾草綠 + 炭黑、低飽和、書脊意象、寬字距大寫」，走 **編輯感 / 自然紙質** 路線，不是科技藍、不是 AI 漸層。

這個方向跟產品本質（讀章節、書庫、閱讀器）很搭，而且**沒有踩到 AI 設計的常見地雷**（無純黑、無過飽和、無紫藍漸層、單一強調色）。底子是好的。

---

## 1. 品牌資產拆解

### 1.1 App Icon — `docs/monori_icon_extra_thick_bars.html`

| 項目 | 值 | 評語 |
|---|---|---|
| 畫布 | 1024 × 1024 | 正確的母檔尺寸 |
| 背景色 | `#A8B9A0`（鼠尾草綠 / sage） | 飽和度約 15%，沉穩、自然，過關 |
| 圖形色 | `#333333`（炭黑） | 不是純黑，符合規範 |
| 圖形 | 三根粗直條，中間那根頂端有一個向下的 V 凹槽 | 讀起來像「書架上的書脊」也像抽象的「M」（Monori）。中間的凹槽是視覺焦點 |
| 圓角 | `rx=220`（約 21.5%） | **這裡有問題，見 §3.1** |

意象判讀：三根書脊 = 書庫；中間 V 凹槽 = 書籤緞帶尾 / 翻開的書 / 字母 M 的頂點。簡潔、可記、縮小到 home screen 還認得出來。

### 1.2 標準字 Wordmark — `docs/monori_wordmark.html`

| 項目 | 值 | 評語 |
|---|---|---|
| 字樣 | `MONORI`（全大寫） | logotype 用全大寫 OK（跟 UI 小標題全大寫是兩回事） |
| 字體 | `font-family: sans-serif`（泛用） | **這是 placeholder，不是真的字體選擇，見 §3.2** |
| 字重 | 600（SemiBold） | 合理 |
| 字距 | `0.15em`（寬） | 寬字距 → 幾何、安靜、編輯感，跟 icon 調性一致 |
| 顏色 | `#333333` | 跟 icon 同一支炭黑，統一 |

### 1.3 配色（Stitch「配色」）

目前只有 **2 色**：
- 品牌綠 `#A8B9A0`
- 墨色 `#333333`
- （隱含白 / 紙底）

2 色當 logo 夠用，但**當成整個 app 的色彩系統不夠**，需要擴成 token（見 §4）。

---

## 2. 現況稽核（app 目前長怎樣）

用 redesign-skill 的稽核表，對應到這個 iOS 專案的實況：

| 稽核項 | 現況 | 判定 |
|---|---|---|
| Asset Catalog | **完全沒有**（`*.xcassets` 一個都沒有） | 🔴 沒地方放 app icon 跟顏色 |
| App Icon | 無自訂 icon（用系統預設白底） | 🔴 缺 |
| 強調色 Accent | 用系統 `Color.accentColor` = **iOS 預設藍** | 🟡 跟品牌綠衝突 |
| 品牌色 | app 內 **0 個品牌色**，全用系統色（`.systemBackground` / `.secondary` / `.secondarySystemFill`） | 🟡 全空白＝改造空間最大 |
| 字體 | 系統 SF Pro | 🟢 iOS 原生正解，**不用換**（這跟 web 不一樣） |
| 閱讀器底色 | dark `#1c1b19`（暖調近黑） | 🟢 剛好跟鼠尾草綠和諧 |
| App 名稱 | `Chapterly` 寫死在 ~30 個檔案 + `project.yml` + package `ChapterlyCore` | 🟡 改名是另一條工 |

目前用到系統藍 accent 的地方（改 accent 會直接影響）：
- 書籤已選 icon：`App/Features/Reader/ReaderView.swift:312`、`App/Features/Library/CollectionTOCView.swift:147`
- Browse 已選 tint：`App/Features/Browse/BrowseView.swift:58`

**好消息**：app 現在幾乎沒有自訂視覺，等於白紙。導入品牌不會跟既有設計打架，風險低。

---

## 3. 關鍵問題與風險（動手前一定要先解的）

### 3.1 🔴 Icon 圓角會「雙重圓角」

iOS 會自己幫 app icon 套上它的 squircle（超橢圓）遮罩。母檔如果**自己先加了 `rx=220` 圓角**，匯出後會變成「圓角方形再被 iOS 圓角一次」，邊角出現空隙 / 形狀怪。

**修法**：母檔要出成**完全直角的正方形**（背景填滿到邊，`rx=0`），把圓角交給 iOS。`docs/` 的 SVG 當展示稿可保留圓角，但**匯出 app icon 用的 PNG 要去掉 `rx`**。

### 3.2 🟡 標準字字體還沒定

`sans-serif` 是泛用 fallback，不是決定。要選一支真的字體，logo 才會一致、可重製。配 icon 的幾何書脊，建議幾何感的 grotesque（給你選，見 §7 決策）。

### 3.3 🔴 鼠尾草綠**不能**直接拿來當小元件的 accent（對比不足）

實算 WCAG 對比：

| 前景 / 背景 | 對比 | 結論 |
|---|---|---|
| `#A8B9A0` 綠 字/icon 放在白底 | **2.08 : 1** | ❌ 不過（UI 元件要 ≥ 3:1，文字要 ≥ 4.5:1） |
| `#333` 字 放在 `#A8B9A0` 綠底 | 6.08 : 1 | ✅ 過 |
| 白字 放在 `#A8B9A0` 綠底 | 2.08 : 1 | ❌ 不過 |
| `#333` 字 放在白底 | 12.6 : 1 | ✅ 很好 |

意思是：**鼠尾草綠只適合當「大面積底色」（icon、header、色塊），上面壓炭黑字。** 但如果直接把 iOS `accentColor` 換成 `#A8B9A0`，那「已選書籤」「Browse 已選」這種白底上的小綠 icon 會**幾乎看不清楚 / 不過 a11y**。

**修法**：用**兩階綠**（見 §4）——淺鼠尾草當底色、深森綠當互動強調色。

---

## 4. 建議色彩系統（把 2 色擴成 token）

落地方式：建一個 `Assets.xcassets`，把這些做成 **Color Set**（含 Any/Dark 兩種 appearance），SwiftUI 直接 `Color("BrandSage")` 取用。

| Token | Light | Dark | 用途 |
|---|---|---|---|
| `BrandSage` | `#A8B9A0` | `#A8B9A0` | 大面積底色、icon 底、裝飾色塊；dark mode 下對比足，可當強調 |
| `AccentForest` | `#5C7150`（深森綠，待你確認色階） | `#A8B9A0` | **互動強調色**（取代系統藍）：已選書籤、已選 tint、主按鈕底配白字 |
| `Ink` | `#333333` | `#ECE9E2`（暖白） | 主文字 |
| `Paper` | `#FBFAF7`（暖白，非純白） | `#1C1B19`（沿用閱讀器暖近黑） | 背景 |

對比檢查（淺色）：`AccentForest #5C7150` 放白底 ≈ **5.3 : 1** ✅（當文字、當 icon、當白字按鈕底都過）。

重點規則（redesign-skill）：
- **單一強調色**：全 app 統一用 `AccentForest`，不要某一頁又冒出藍 CTA。
- **暖灰統一**：背景用暖白 `#FBFAF7` 不要純白；dark 沿用 `#1C1B19`，整支同一個暖色家族。
- **dark mode 一起設計**：鼠尾草綠在深底上對比好，dark mode 直接拿 `#A8B9A0` 當強調色。

---

## 5. 套用範圍（品牌進到 app 哪些地方）

1. **App Icon**：新建 `Assets.xcassets/AppIcon.appiconset`，放 1024 直角母檔（§3.1）。
2. **Accent Color**：新建 `AccentColor` color set = `AccentForest`；`project.yml` 設 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`。系統藍的書籤/Browse tint 自動變森綠。
3. **Launch Screen**：目前 `UILaunchScreen: {}`（空白）。可放置中 wordmark + 暖白底，第一眼就是品牌。
4. **書庫 / 導覽標題**：大標題區可用 wordmark 或品牌綠色塊點綴。
5. **閱讀器**：底色已是 `#1C1B19`，跟品牌一致，幾乎不用動；可把進度/書籤強調色接上 token。

---

## 6. 改名 Chapterly → Monori（獨立工作流，風險另計）

這是**機械式大重構**，跟「視覺品牌」分開，建議分兩步做。範圍：

- `project.yml`：`name`、target 名、`CFBundleDisplayName`、`bundleIdPrefix`（`dev.chapterly` → `dev.monori`）
- Swift package：`ChapterlyCore` → `MonoriCore`（每個 `import ChapterlyCore` 都要改）
- ~30 個檔案有 `Chapterly` 字樣（含 `ChapterlyApp.swift`、`config.json`、測試）
- 改完要 `xcodegen generate` 重生專案，再跑 `./scripts/verify.sh`

⚠️ **風險**：改 **bundle id** 等於變成「新 app」——TestFlight / 裝置上會被當另一支，Patreon 登入狀態（目前 simulator 上的）可能要重登。改名建議挑一個你願意重登 Patreon 的時間做。

> 注意：CFBundleDisplayName（home screen 顯示名）可以**先單獨改成 Monori**，不動 bundle id，這樣不影響登入狀態，是低風險的第一步。

---

## 7. 建議執行順序 + 需要你決定的事

依 redesign-skill「低風險高回報先做」：

1. 先定 icon 母檔（去圓角）→ 出 1024 PNG
2. 建 `Assets.xcassets` + AppIcon + AccentColor（森綠）
3. 顯示名 `CFBundleDisplayName` 改 Monori（低風險）
4. Launch Screen 放 wordmark
5. （另排）全面改名 + bundle id（高風險，挑時間）

**決策（2026-06-20 已定）：**

1. ✅ **強調色** = `#5C7150` 深森綠（全 app 互動色，過 AA）。
2. ✅ **標準字** = **Sora 600**（Google Fonts，可商用）。寬字距 0.13em，幾何感搭配書脊 icon。
   - 注意：wordmark 通常做成**向量資產（SVG/PNG）**放進 app，字體只在「設計當下」需要，**不必嵌進 app**，無授權／包大小問題。
3. ✅ **改名** = Chapterly→Monori **連 bundle id 全改**（`dev.chapterly`→`dev.monori`、`ChapterlyCore`→`MonoriCore`、~30 檔）。
   - ⚠️ bundle id 改 = 裝置／TestFlight 視為新 app，**需重登 Patreon**；挑你願意重登的時間做。
   - 這是大型機械重構，建議跟視覺品牌**分兩個 commit / 兩個工作段**，每段做完跑 `./scripts/verify.sh`。

**三項全數已定，可進入實作。**

---

## 附錄：實算對比數值（WCAG 2.x 相對亮度）

- `#A8B9A0` 相對亮度 L ≈ 0.455
- `#333333` L ≈ 0.0331
- `#5C7150` L ≈ 0.147
- 對比 = (L1 + 0.05) / (L2 + 0.05)
