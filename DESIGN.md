# Monori 設計系統：Uguisu Zen

> Monori 是讓故事安靜浮現的閱讀居所，而非一個搶走注意力的媒體
> App。本文件是所有 SwiftUI／UIKit 畫面、閱讀器 CSS 與 Stitch 產生
> 畫面的唯一視覺準則；新增或重構 UI 時，應以此文件優先於既有局部
> 樣式。所有使用者介面文案採繁體中文。

## 1. 視覺主題與氛圍

**Uguisu Zen** 取自日式空間美學的「間（Ma）」與「靜（Sei）」。它是
一個帶些暖意、留白充足、穩定而內斂的閱讀環境；介面應退到故事之後，
讓讀者先看見文字，之後才注意到控制項。

- **密度：3／10（Gallery Airy）**：寬鬆、低噪音；優先用留白、細分隔線
  與表面色差建立結構，而非增加卡片與裝飾。
- **變化：3／10（Predictable）**：閱讀流程清楚、版面穩定。不要為了視覺
  效果打破內容順序、重疊元素或製造非必要的不對稱。
- **動態：2／10（Static Restrained）**：互動只提供必要回饋，不讓任何元素
  持續索取注意力。
- 所有畫面使用平面、實色、不透明的層次。Washi White 與 Stone Grey 的
  微差，才是主要的深淺語言；Uguisu Green 不是用來填滿畫面的背景色。

## 2. 色彩與使用角色

### 基底、文字與品牌

| Token | 色碼 | 固定角色 |
| --- | --- | --- |
| **Washi White（和紙白）** | `#FBF9F8` | 全域主畫布、閱讀器紙面與大面積背景；永不以純白取代。 |
| **Stone Grey（石灰）** | `#F2F0ED` | 不透明容器、分區底、選取列與 1px 分隔線；用來在白色畫布中建立克制層次。 |
| **Sumi Ink（炭黑）** | `#1C1B19` | 標題、正文與高重要性線條；永不使用 `#000000`。 |
| **Uguisu Green（鶯色）** | `#A8B9A0` | 僅限品牌標誌、App icon、啟動畫面與已選取的導航按鈕／圖示。不可作為一般按鈕、卡片或整片背景。 |
| **Uguisu Dark** | `#7D8E76` | 深色模式中的品牌識別，或必要的高對比「已選取導航」狀態；用途與 Uguisu Green 相同。 |
| **Uguisu Light** | `#C5D1BF` | 品牌資產內的淺色層次；不得用作通用 UI 填色或新增第二個醒目色。 |

### 功能色（不是品牌色）

| Token | 色碼 | 固定角色 |
| --- | --- | --- |
| **Bookmark Red** | `#A64D4D` | 僅限已收藏書籤與需要被保留的重要標記。不可用於錯誤、CTA 或一般警告。 |
| **Highlight Gold** | `#D4B483` | 僅限新章節、追更進度完成或閱讀進度的細小提示；不得鋪滿容器。 |

色彩規則：

- Washi White 為預設背景，Stone Grey 為第二層表面；兩者以完整不透明填色
  區分，不以透明度、漸層或毛玻璃區分。
- 主要行動按鈕使用 Sumi Ink 文字與 Stone Grey／Washi White 的平面表面，
  以邊框、字重與位置表達優先順序。綠色只表達「你正在這裡」的導航狀態或
  Monori 本身的品牌識別。
- 深色模式應維持相同的角色關係：深炭底、淺暖灰表面與高可讀文字；不得把
  大面積 UI 改成飽和綠色。必要時才以 Uguisu Dark 表示已選取導航。
- 不使用系統預設藍色作為額外重點色。錯誤與破壞性操作沿用平台可及性語義色，
  但不借用 Bookmark Red。

### 深色模式實作映射

| Token | 色碼 | 角色 |
| --- | --- | --- |
| **Dark Canvas** | `#1C1B19` | Washi White 在深色模式的對應主畫布。 |
| **Dark Stone Surface** | `#292723` | Stone Grey 的不透明容器對應色。 |
| **Dark Ink** | `#F2F0ED` | Sumi Ink 在深色模式的主要文字。 |
| **Dark Secondary Ink** | `#B9B5AF` | metadata 與次要線條文字。 |
| **Dark Divider** | `#3B3833` | 不透明 hairline divider。 |
| **Selected Navigation** | `#A8B9A0` | 深色模式下已選取的導航圖示。 |

淺色模式下，已選取導航圖示使用 `#7D8E76`：`#A8B9A0` 在 Washi White 上的
對比不足以承擔小型控制項。導航文字仍以 Sumi Ink／Dark Ink 保持可讀性。

## 3. 字體架構

### UI、導航與控制項：Manrope

- 所有 App chrome、標題、按鈕、標籤、清單與設定頁以 **Manrope** 為核心。
  字重以 400、500、600、700 建立層級，不以過大的字級或色彩堆疊製造重量。
- 導航、按鈕與全大寫短標籤採 `0.05em` letter-spacing；一般 UI 文字可在
  `0.01em–0.03em` 間微幅追蹤。不要壓縮字距。
- UI 內文行高為 `1.5`；小型 metadata 也要保有可辨識的行高。標題寧可用字重
  與留白區分，不做誇張 display type。
- 字型載入失敗時，使用具備繁體中文覆蓋的無襯線 fallback；不得以 Inter、
  SF Pro 或系統字體作為此視覺系統的設計基準。

### 閱讀內容：Source Serif 4（預設）；使用者可選擇本機匯入字型

- 閱讀器正文預設以 **Source Serif 4** 為核心；繁體中文缺字時以 **Noto Serif
  TC** 補足字形，兩者都必須維持襯線閱讀節奏。閱讀器不得回退為 UI sans-serif。
- 使用者可從「設定 → 外觀 → 閱讀字體」匯入 `.ttf` 或 `.otf` 字型，並選擇
  作為閱讀器正文字型。匯入字型僅存於 app sandbox，不上傳、不隨「清除書庫
  資料」刪除。使用者匯入字型的 fallback 仍為 **Noto Serif TC** 與 serif。
- 正文預設 18–20pt，行高 `1.9`（可在 `1.8–2.0` 間由閱讀偏好調整），段落間距
  至少 `0.85em`。行寬以約 28–34 個漢字為目標，避免寬到需要視線大幅橫移。
- 章名可使用 Source Serif 4 semibold；作者、章節 metadata 與閱讀工具列仍使用
  Manrope，讓內容與控制層明確分離。
- 不使用 Times New Roman、Georgia、Garamond、Palatino 或其他通用 serif；不將
  Manrope 用於長篇正文。

## 4. 空間、網格與版面

- 使用 **8pt 網格**：8、16、24、32、40、48、64。內容區最小內距為 24pt，
  主要閱讀與設定區優先使用 32pt；不要回落到擁擠的 16pt 畫面邊距。
- 區塊之間使用 32–48pt，主要畫面段落使用 48–64pt。留白是內容的框架，不是
  尚未填滿的空洞。
- 表單標籤置於欄位上方；輔助訊息或錯誤訊息置於欄位下方。避免浮動標籤與
  過度密集的設定列。
- iPhone 以單欄為主；iPad 可在不削弱閱讀行寬的前提下顯示目錄與內容兩欄。
  所有觸控目標至少 44 × 44pt，文字必須支援 Dynamic Type，且不能以截斷正文
  換取固定高度。
- 元素不得重疊、漂浮在不相干內容之上或依賴絕對定位堆疊。內容的順序必須與
  視覺順序一致。

## 5. 形狀、圖示與元件

### 形狀與表面

- 統一使用 **8pt** 或 **12pt** 圓角；8pt 適合控制項與列，12pt 適合需要分組的
  容器。禁止膠囊外觀，除非該形狀是有明確語義的圓形圖示按鈕。
- 卡片只在確實需要分組或浮現層級時使用。一般清單以 Stone Grey 分隔線、
  Washi White 畫布與負空間處理，不堆疊厚重卡片。
- 表面和容器一律不透明；禁止 `Material`、blur、vibrancy、半透明 toolbar、
  浮動玻璃膠囊與 backdrop filter。底部工具列可有一次極淡擴散陰影
  `rgba(0,0,0,0.03)`，其餘不使用陰影。

### 圖示

- 只使用與 Manrope 筆畫相稱的 line-style 圖示。現有來源與底部導航圖示仍由
  [`App/Features/Shared/MonoriIcons.swift`](App/Features/Shared/MonoriIcons.swift)
  的自繪 `Shape` 擔任單一來源；不可用 SF Symbols 取代它們。
- 圖示以 Sumi Ink／次要文字色呈現；只有已選取的導航圖示可使用 Uguisu Green。
  書籤圖示在已收藏時使用 Bookmark Red。
- 新增來源時，仍應在 `MonoriIcons.swift` 以標準化 0…1 畫布繪製 `Shape`，並由
  `SourceGlyph` 同時供 Browse picker 與 Library 使用；不要在使用者介面採用
  `SourceProvider.iconSystemName`。

### 按鈕、清單與狀態

- **按鈕：**平面、不透明、8pt 圓角。主要操作以 Sumi Ink 文字、清楚的 1px
  Stone Grey 邊界與充足內距建立份量；按下時僅 `scale(0.98)` 或下移 1pt，
  不發光、不變玻璃、不中斷版面。
- **導航：**選取狀態用 Uguisu Green；未選取狀態以 Sumi Ink 的次要權重呈現。
  不以綠色填滿整個 tab bar 或一般行動按鈕。
- **列表／集合：**以題名、metadata、細分隔線和至少 16pt 垂直留白建立節奏。
  不做三等寬卡片網格，也不把每一列放進獨立浮卡。
- **輸入欄位：**不透明 Washi White 填色與 Stone Grey 1px 邊界，label 在上、錯誤
  在下。focus 用 Sumi Ink 邊界或可及性語義提示，不套用綠色光暈。
- **載入：**使用與實際內容同尺寸的低對比骨架，或現有單一線性進度列；禁止
  泛用圓形 spinner、跳動點與無限閃爍。
- **空／錯誤狀態：**簡短說明下一步，維持 Washi／Stone 的平面構圖；不使用
  emoji、插畫噪音或泛泛的行銷句。

## 6. 閱讀器實作準則

- 閱讀器是全 App 最安靜的表面：Washi White 紙面、Source Serif 4／Noto Serif TC
  正文、Sumi Ink 文字與極寬行距。讀者感受的是紙張與文字，不是 WebView 的原貌。
- Reader chrome 必須扁平且不透明，顯示時以 Washi White 或 Stone Grey 明確落地；
  隱藏時不留下半透明浮動控制項。工具列文字與圖示使用 Manrope／line icons。
- 段落、引用、章節標題與分隔線以尺度、行高與留白分級；不要以彩色底塊、重陰影
  或多種強調色搶走小說內容。
- Reader mode 對 library chapters（`foreignPageTitle == nil`）永遠啟用，沒有
  per-chapter opt-out。Reader CSS 與 native preferences 都必須維持上述字型、
  行高與不透明表面規則。

## 7. 動態與互動

- 只為使用者觸發的變化提供 150–250ms 的溫和 ease-out 回饋，例如工具列顯隱、
  書籤切換與來源切換。尊重 Reduce Motion，啟用時取消非必要動畫。
- 僅動畫 `opacity` 與 `transform`；不要動畫位置尺寸、模糊、陰影、背景漸層或
  layout constraint。不得有持續 pulse、float、shimmer、typewriter 或自動輪播。
- 需要到達感時可使用克制 haptic；動畫應確認操作已發生，不能成為另一個焦點。

## 8. 明確禁止事項

- 禁止 iOS 原生半透明玻璃、Liquid Glass、浮動膠囊、blur、vibrancy、透明 toolbar
  與 backdrop filter。
- 禁止把 Uguisu Green 用在導航／品牌識別以外的填色、CTA、卡片或大面積背景。
- 禁止純黑、純白、霓虹色、紫藍色發光、彩虹／文字漸層、重陰影與過飽和 accent。
- 禁止 Inter、SF Pro 作為設計字體；禁止將 UI sans-serif 用於長篇閱讀，或用通用
  serif 取代 Source Serif 4／Noto Serif TC。
- 禁止 emoji、泛用 AI 行銷語（如「無縫」、「下一代」、「解鎖」）、假數據、
  捲動提示箭頭與裝飾性 filler text。
- 禁止重疊內容、三欄等寬功能卡、無理由的卡片堆疊、客製滑鼠游標與任何無限循環
  的裝飾動畫。
