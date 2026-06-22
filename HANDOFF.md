# HANDOFF

> 上次 session: 2026-06-20（Monori 視覺品牌套用完成）
> 下次接手請從「接手要做的事」開始 —— 主任務：全域改名 Chapterly → Monori

## 狀態
視覺品牌層已完成並合進 `ui-op`；app 顯示名已是 Monori，但 **internal 模組 / bundle id / 專案名仍是 Chapterly**。下一階段是全域改名。
- 測試/建置狀態：✅ 綠（`./scripts/verify.sh`，125/125，BUILD SUCCEEDED）
- 分支 ＠ 最後 commit：`ui-op @ 0faaaae`
- 工作樹：clean

## ✅ 本次完成（2026-06-20）
- **LaunchScreen.storyboard 修好**：手寫 storyboard 原本 `targetRuntime="AppleCocoa"`（macOS）→ ibtool error -1。改 `iOS.CocoaTouch` + `viewLayoutGuide key="safeArea"`，ibtool 0 error/warning/notice
- **視覺品牌套用**（commit `0faaaae`）：`App/Assets.xcassets/` 新增 AppIcon（1024 三書脊、去 rx 圓角）、AccentColor `#5C7150`、BrandSage `#A8B9A0`、LaunchMark @1/2/3x；LaunchScreen.storyboard（BrandSage 底 + icon + "monori" 置中）；`project.yml` 加 APPICON/GLOBAL_ACCENT 設定 + `CFBundleDisplayName=Monori` + `UILaunchStoryboardName`；Info.plist 同步
- **SVG 去圓角**（commit `0121999`）：icon 母檔移除 `rx="220"`，避免與 iOS squircle 雙重圓角
- **品牌評估報告**（commit `efd8f05`）：`docs/monori_rebrand_report.md`
- PNG 由 Swift + CoreGraphics 產生（系統無 ImageMagick/rsvg/Pillow）

## 🔄 進行中
無。視覺層收尾，改名尚未開始。

## 🚧 試過但行不通（避免重踩）
- **手寫 launch storyboard 用 `targetRuntime="AppleCocoa"`** → ibtool error -1（那是 macOS runtime）。iOS 必須 `iOS.CocoaTouch`，且 safe-area guide 的 key 是 `safeArea` 不是 `safeAreaLayoutGuide`。對照樣板：`/Applications/Xcode.app/.../Templates/.../iOS App Base.xctemplate/LaunchScreen.storyboard`

## ⚡ 接手要做的事 —— 全域改名 Chapterly → Monori

**先決：開新分支**（建議 `rename/monori`）。改 bundle id 會讓 Patreon 登入失效 + 本機書庫資料重置，必須隔離成獨立 PR。

改名分兩層 —— **重點：不要整包 `s/Chapterly/Monori/` + `s/chapterly/monori/`**，會打爛 JS↔Swift / CSS 跨檔契約。

### Tier A — 要改（使用者可見身分 + Swift 模組）
1. **`project.yml`**：`name: Chapterly`→`Monori`、`bundleIdPrefix: dev.chapterly`→`dev.monori`、package path `ChapterlyCore`→`MonoriCore`、target name `Chapterly`→`Monori`、package ref `ChapterlyCore`→`MonoriCore`
2. **目錄/檔案 `git mv`**：
   - `ChapterlyCore/` → `MonoriCore/`
   - `MonoriCore/Sources/ChapterlyCore/` → `MonoriCore/Sources/MonoriCore/`
   - `MonoriCore/Tests/ChapterlyCoreTests/` → `MonoriCore/Tests/MonoriCoreTests/`
   - `.../ChapterlyCore.swift` → `.../MonoriCore.swift`
   - `App/ChapterlyApp.swift` → `App/MonoriApp.swift`
3. **`Package.swift`**：`name`/`products`/`targets` 的 `ChapterlyCore`/`ChapterlyCoreTests` → `MonoriCore`/`MonoriCoreTests`
4. **Swift source**：每個 `import ChapterlyCore` 與 `@testable import ChapterlyCore` → `MonoriCore`；`@main struct ChapterlyApp` → `MonoriApp`
5. **scripts**（`smoke-auto.sh`/`smoke-diagnostics.sh`/`ui-driver.sh`/`ui-preflight.sh`/`verify.sh`/`check-hooks.sh`）：
   - `Chapterly.xcodeproj` → `Monori.xcodeproj`
   - `-scheme Chapterly` → `-scheme Monori`
   - `BUNDLE_ID="dev.chapterly.Chapterly"` → `dev.monori.Monori`
   - log predicate `subsystem == "dev.chapterly"` → `dev.monori`
   - DerivedData glob `Chapterly-*` → `Monori-*`
6. **文件**：README.md / CLAUDE.md / AGENTS.md / COMPLIANCE.md / WIKI_SYNC.md / SIMULATOR_PLAYBOOK.md / config.json / .env.example 內文字 reference

### Tier B — 不要改（內部識別碼，改了零使用者收益、純風險）
這些是 JS↔Swift / Swift↔CSS 跨檔契約或內部守衛，必須三邊同步否則 reader 字級控制 / collection import 會壞：
- **訊息 handler 名**：`chapterlyImport` / `chapterlyCollectionLink`（`ScriptMessageRouter.swift` ↔ `CollectionDetect.js` / `CollectionImport.js` / `DrawerDiagnostics.js`）
- **CSS 自訂屬性**：`--chapterly-font-size` / `--chapterly-line-height`（`ReaderStyler.swift` 設值 ↔ `ReaderRuleset.css` 讀值）
- **JS 全域守衛 + CSS class / style id**：`window.__chapterly*`、`chapterly-fade`、`chapterly-card-style`、`chapterly-reader-style`

### 驗證順序
1. `xcodegen generate` → `xcodebuild -list -project Monori.xcodeproj`（確認 scheme = Monori）
2. `./scripts/verify.sh`（須回綠 125/125）
3. 使用者手動：重裝 app → **重登 Patreon**（bundle id 變 = 新 sandbox）→ 重新 import 一個 collection（SwiftData 容器重置）

## ⚠️ 注意事項
- **`Chapterly.xcodeproj` 是 gitignored 產生物**（非追蹤檔）→ 不用 git mv；改 `project.yml` 的 `name:` 後 `xcodegen generate` 即變 `Monori.xcodeproj`。腳本內硬寫的 `Chapterly.xcodeproj` 才要手改。
- **持久層無 App Group、無具名 UserDefaults suite、SwiftData 用預設容器** → 沒有遷移碼要動；但 bundle id 一變，本機書庫 + `reader.fontSize`/`reader.lineSpacing`（`UserDefaults.standard`）會重置（dev app 可接受，使用者重 import 即可）。
- `CFBundleDisplayName` 已是 Monori（本次已改），改名階段不用再動。
- `verify.sh` 有 build↔swift-test 共用 `.build` 的 race（會印 SQLITE_IOERR 但測試其實過），改名後若見此 IOERR 別當程式錯誤（見 MEMORY.md 踩過的坑）。

## 📁 本次修改的檔案
- `App/Assets.xcassets/**`（新增）— AppIcon / AccentColor / BrandSage / LaunchMark
- `App/LaunchScreen.storyboard`（新增）— 啟動畫面
- `App/Info.plist` — CFBundleDisplayName=Monori、UILaunchStoryboardName
- `project.yml` — APPICON/GLOBAL_ACCENT 設定 + display name + launch storyboard
- `docs/monori_icon_extra_thick_bars.html` — 去 rx 圓角
- `docs/monori_rebrand_report.md`（新增）— 品牌評估報告

## 🔗 相關資源
- 品牌報告：`docs/monori_rebrand_report.md`
- iOS launch storyboard 樣板：`/Applications/Xcode.app/Contents/Developer/Library/Xcode/Templates/Project Templates/MultiPlatform/Application/iOS App Base.xctemplate/LaunchScreen.storyboard`
- Standard verification：`./scripts/verify.sh`
- Simulator 操作手冊：`SIMULATOR_PLAYBOOK.md`
