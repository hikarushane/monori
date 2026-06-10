# Chapterly MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open-source, sideloaded, local-only iOS WKWebView reading shell for the user's own Patreon session, with collection-based chapter navigation, reader CSS cleanup, and local reading progress.

**Architecture:** A pure-logic Swift package (`ChapterlyCore`) holds everything testable on macOS via `swift test`: URL normalization, strict script-message payload validation, chapter-map merging, navigation policy, SwiftData models and store, and the bundled JS/CSS assets. A thin Xcode app target (generated with XcodeGen) hosts the SwiftUI screens and the WKWebView. The native side is a content firewall: injected JS may only post whitelisted metadata fields; everything else is rejected before persistence.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData, WebKit (WKWebView), XCTest, XcodeGen. iOS 17 minimum; package also builds for macOS 14 so logic tests run with `swift test`.

**Spec:** `docs/superpowers/specs/2026-06-10-chapterly-design.md` — read it first. Its §2 forbidden list is law: never read cookies, never intercept network responses, never call Patreon APIs, never store post bodies or HTML.

**Design direction:** Spec §5 (calm editorial reading app, list-first, native typography) is baked into the UI tasks below using native iOS idioms. If the taste-skill workflow (imagegen-frontend-mobile reference screens → DESIGN.md) is available in the executing environment, it may run before Task 11 and refine the UI tasks' visual details; it must not change any logic, model, or compliance behavior.

**Conventions for every task:**
- Package tests: `swift test --package-path ChapterlyCore` (run from repo root `/Users/shane_yeh/Projects/Chapterly`).
- App build: `xcodebuild -project Chapterly.xcodeproj -scheme Chapterly -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Commit after every green test run. Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Project scaffold

**Files:**
- Create: `.gitignore`, `.env`, `.env.example`, `config.json`
- Create: `ChapterlyCore/Package.swift`
- Create: `ChapterlyCore/Sources/ChapterlyCore/ChapterlyCore.swift`
- Create: `ChapterlyCore/Tests/ChapterlyCoreTests/SmokeTests.swift`
- Create: `project.yml` (XcodeGen)
- Create: `App/ChapterlyApp.swift`, `App/AppRootView.swift`, `App/Info.plist`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
.DS_Store
xcuserdata/
DerivedData/
.build/
*.xcodeproj
.env
```

(`*.xcodeproj` is gitignored because XcodeGen regenerates it from `project.yml`.)

- [ ] **Step 2: Create config placeholders**

The app has no secrets and no environment variables; these files exist to satisfy repo conventions and document that fact.

`.env`:
```
# Chapterly has no secrets. Intentionally empty.
```

`.env.example`:
```
# Chapterly has no secrets. Intentionally empty.
# Never add a Patreon client_secret here or anywhere in this repo.
```

`config.json`:
```json
{
  "note": "Chapterly is local-only. No backend, no API keys, no remote config."
}
```

- [ ] **Step 3: Create the Swift package**

`ChapterlyCore/Package.swift`:
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ChapterlyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ChapterlyCore", targets: ["ChapterlyCore"])
    ],
    targets: [
        .target(
            name: "ChapterlyCore",
            resources: [.process("Assets")]
        ),
        .testTarget(
            name: "ChapterlyCoreTests",
            dependencies: ["ChapterlyCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
```

`ChapterlyCore/Sources/ChapterlyCore/ChapterlyCore.swift`:
```swift
public enum ChapterlyCore {
    public static let version = "0.1.0"
}
```

Create empty dirs with placeholder files so resources compile:
`ChapterlyCore/Sources/ChapterlyCore/Assets/.gitkeep` and `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/.gitkeep`.

`ChapterlyCore/Tests/ChapterlyCoreTests/SmokeTests.swift`:
```swift
import XCTest
import ChapterlyCore

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(ChapterlyCore.version, "0.1.0")
    }
}
```

- [ ] **Step 4: Run package tests**

Run: `swift test --package-path ChapterlyCore`
Expected: 1 test, PASS.

- [ ] **Step 5: Create app shell**

`App/ChapterlyApp.swift`:
```swift
import SwiftUI
import SwiftData
import ChapterlyCore

@main
struct ChapterlyApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
```

`App/AppRootView.swift`:
```swift
import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            Text("Browse").tabItem { Label("Browse", systemImage: "globe") }
            Text("Library").tabItem { Label("Library", systemImage: "books.vertical") }
            Text("Settings").tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
```

`App/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key><string>Chapterly</string>
    <key>UILaunchScreen</key><dict/>
</dict>
</plist>
```

- [ ] **Step 6: Create `project.yml` and generate the Xcode project**

`project.yml`:
```yaml
name: Chapterly
options:
  bundleIdPrefix: dev.chapterly
  deploymentTarget:
    iOS: "17.0"
packages:
  ChapterlyCore:
    path: ChapterlyCore
targets:
  Chapterly:
    type: application
    platform: iOS
    sources: [App]
    info:
      path: App/Info.plist
      properties:
        CFBundleDisplayName: Chapterly
        UILaunchScreen: {}
    dependencies:
      - package: ChapterlyCore
```

Run: `which xcodegen || brew install xcodegen`
Run: `xcodegen generate`
Expected: `Chapterly.xcodeproj` created.

- [ ] **Step 7: Build the app**

Run: `xcodebuild -project Chapterly.xcodeproj -scheme Chapterly -destination 'platform=iOS Simulator,name=iPhone 15' build`
(If "iPhone 15" is unavailable, list simulators with `xcrun simctl list devices available` and substitute any iOS 17+ device. Use the same substitution in all later tasks.)
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Scaffold ChapterlyCore package and app shell"
```

---

### Task 2: URLNormalizer

Spec §3.3 "URL normalization": one function, used for storage, prev/next matching, and merge-by-URL.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/URLNormalizer.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/URLNormalizerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import ChapterlyCore

final class URLNormalizerTests: XCTestCase {
    func testNormalizesHostSchemeAndTrailingSlash() {
        let url = URL(string: "http://patreon.com/posts/some-post-123456/")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString,
                       "https://www.patreon.com/posts/some-post-123456")
    }

    func testStripsTrackingParamsAndFragment() {
        let url = URL(string: "https://www.patreon.com/posts/abc-987?utm_source=feed&utm_medium=x&fan_landing=true&mc_cid=1#comments")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString,
                       "https://www.patreon.com/posts/abc-987")
    }

    func testKeepsNonTrackingQuery() {
        let url = URL(string: "https://www.patreon.com/collection/12345?view=expanded")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString,
                       "https://www.patreon.com/collection/12345?view=expanded")
    }

    func testNonPatreonURLReturnsNil() {
        XCTAssertNil(URLNormalizer.normalize(URL(string: "https://example.com/posts/1")!))
    }

    func testRootPathKeepsSlash() {
        let url = URL(string: "https://patreon.com/")!
        XCTAssertEqual(URLNormalizer.normalize(url)?.absoluteString, "https://www.patreon.com/")
    }

    func testStringConvenience() {
        XCTAssertEqual(URLNormalizer.normalize("https://patreon.com/posts/x-1?utm_campaign=z")?.absoluteString,
                       "https://www.patreon.com/posts/x-1")
        XCTAssertNil(URLNormalizer.normalize("not a url ::"))
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --package-path ChapterlyCore`
Expected: FAIL — `cannot find 'URLNormalizer'`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Single source of truth for Patreon URL identity (spec §3.3).
/// Returns nil for anything that is not a patreon.com URL.
public enum URLNormalizer {
    private static let trackingPrefixes = ["utm_", "mc_"]
    private static let trackingExact: Set<String> = ["fan_landing", "ref"]

    public static func normalize(_ url: URL) -> URL? {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host?.lowercased(),
              host == "patreon.com" || host.hasSuffix(".patreon.com")
        else { return nil }

        comps.scheme = "https"
        comps.host = "www.patreon.com"
        comps.fragment = nil

        if let items = comps.queryItems {
            let kept = items.filter { item in
                let name = item.name.lowercased()
                if trackingExact.contains(name) { return false }
                return !trackingPrefixes.contains { name.hasPrefix($0) }
            }
            comps.queryItems = kept.isEmpty ? nil : kept
        }

        if comps.path.count > 1, comps.path.hasSuffix("/") {
            comps.path = String(comps.path.dropLast())
        }
        if comps.path.isEmpty { comps.path = "/" }

        return comps.url
    }

    public static func normalize(_ string: String) -> URL? {
        guard let url = URL(string: string) else { return nil }
        return normalize(url)
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add ChapterlyCore
git commit -m "Add URLNormalizer for Patreon URL identity"
```

---

### Task 3: PayloadValidator — the content firewall

Spec §3.3 "Script message payload schemas (strict)". Three message types: importer chapter, collection link, progress. JS sends one flat dictionary per chapter.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/Payloads.swift`
- Create: `ChapterlyCore/Sources/ChapterlyCore/PayloadValidator.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/PayloadValidatorTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import ChapterlyCore

final class PayloadValidatorTests: XCTestCase {
    private func validImporterBody() -> [String: Any] {
        [
            "title": "5 脣瓣",
            "url": "https://www.patreon.com/posts/5-123456",
            "visibleDateText": "June 1",
            "collectionName": "【更新中】焚心 The Burning Heart",
            "collectionURL": "https://www.patreon.com/collection/9999",
            "domOrder": 4
        ]
    }

    func testValidImporterPayload() throws {
        let p = try PayloadValidator.validateImporterChapter(validImporterBody()).get()
        XCTAssertEqual(p.title, "5 脣瓣")
        XCTAssertEqual(p.domOrder, 4)
        XCTAssertEqual(p.visibleDateText, "June 1")
    }

    func testNullDateBecomesNil() throws {
        var body = validImporterBody()
        body["visibleDateText"] = NSNull()
        let p = try PayloadValidator.validateImporterChapter(body).get()
        XCTAssertNil(p.visibleDateText)
    }

    func testForbiddenKeyRejectsWholeMessage() {
        for key in ["bodyText", "innerText", "innerHTML", "html", "content",
                    "article", "paragraphs", "images", "comments", "INNERHTML"] {
            var body = validImporterBody()
            body[key] = "anything"
            guard case .failure(let e) = PayloadValidator.validateImporterChapter(body) else {
                return XCTFail("accepted forbidden key \(key)")
            }
            XCTAssertEqual(e, .forbiddenKey(key.lowercased()))
        }
    }

    func testUnknownKeyRejects() {
        var body = validImporterBody()
        body["extra"] = 1
        guard case .failure(.unknownKey("extra")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted unknown key")
        }
    }

    func testMissingRequiredKeyRejects() {
        var body = validImporterBody()
        body.removeValue(forKey: "url")
        guard case .failure(.missingKey("url")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted missing url")
        }
    }

    func testOversizedStringRejects() {
        var body = validImporterBody()
        body["title"] = String(repeating: "x", count: 2000)
        guard case .failure(.tooLarge("title")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted oversized title")
        }
    }

    func testOversizedURLRejects() {
        var body = validImporterBody()
        body["url"] = "https://www.patreon.com/posts/" + String(repeating: "a", count: 3000)
        guard case .failure(.tooLarge("url")) = PayloadValidator.validateImporterChapter(body) else {
            return XCTFail("accepted oversized url")
        }
    }

    func testNotADictionaryRejects() {
        guard case .failure(.notADictionary) = PayloadValidator.validateImporterChapter("a string") else {
            return XCTFail("accepted non-dictionary")
        }
    }

    func testValidProgressPayload() throws {
        let p = try PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/5-123456", "scrollProgress": 0.42]).get()
        XCTAssertEqual(p.scrollProgress, 0.42, accuracy: 0.001)
    }

    func testProgressClampedToUnitRange() throws {
        let p = try PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/x", "scrollProgress": 7.5]).get()
        XCTAssertEqual(p.scrollProgress, 1.0)
    }

    func testProgressRejectsForbiddenExtraField() {
        // Precedence rule: forbidden-key check runs before unknown-key check.
        guard case .failure(.forbiddenKey("html")) = PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/x", "scrollProgress": 0.5, "html": "<p>"])
        else { return XCTFail("accepted forbidden field") }
    }

    func testProgressRejectsUnknownExtraField() {
        guard case .failure(.unknownKey("extra")) = PayloadValidator.validateProgress(
            ["url": "https://www.patreon.com/posts/x", "scrollProgress": 0.5, "extra": 1])
        else { return XCTFail("accepted unknown field") }
    }

    func testValidCollectionLinkPayload() throws {
        let p = try PayloadValidator.validateCollectionLink(
            ["collectionName": "焚心", "collectionURL": "https://www.patreon.com/collection/9999"]).get()
        XCTAssertEqual(p.collectionName, "焚心")
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --package-path ChapterlyCore`
Expected: FAIL — `cannot find 'PayloadValidator'`.

- [ ] **Step 3: Implement payload types**

`Payloads.swift`:
```swift
import Foundation

public struct ImporterChapterPayload: Equatable {
    public let title: String
    public let url: String
    public let visibleDateText: String?
    public let collectionName: String
    public let collectionURL: String
    public let domOrder: Int

    public init(title: String, url: String, visibleDateText: String?,
                collectionName: String, collectionURL: String, domOrder: Int) {
        self.title = title
        self.url = url
        self.visibleDateText = visibleDateText
        self.collectionName = collectionName
        self.collectionURL = collectionURL
        self.domOrder = domOrder
    }
}

public struct CollectionLinkPayload: Equatable {
    public let collectionName: String
    public let collectionURL: String

    public init(collectionName: String, collectionURL: String) {
        self.collectionName = collectionName
        self.collectionURL = collectionURL
    }
}

public struct ProgressPayload: Equatable {
    public let url: String
    public let scrollProgress: Double

    public init(url: String, scrollProgress: Double) {
        self.url = url
        self.scrollProgress = scrollProgress
    }
}

public enum PayloadError: Error, Equatable {
    case notADictionary
    case forbiddenKey(String)   // lowercased key name
    case unknownKey(String)
    case missingKey(String)
    case wrongType(String)
    case tooLarge(String)
}
```

- [ ] **Step 4: Implement validator**

`PayloadValidator.swift`:
```swift
import Foundation

/// Native-side content firewall (spec §3.3). Every WKScriptMessage body passes
/// through here before any other code sees it. Whole-message rejection: one bad
/// field drops the entire payload. Never log payload contents.
public enum PayloadValidator {
    public static let forbiddenKeys: Set<String> = [
        "bodytext", "innertext", "innerhtml", "html", "content",
        "article", "paragraphs", "images", "comments"
    ]
    public static let maxFieldLength = 1024        // titles, names, dates
    public static let maxURLLength = 2048
    public static let maxMessageBytes = 256 * 1024

    // MARK: schemas

    public static func validateImporterChapter(_ body: Any) -> Result<ImporterChapterPayload, PayloadError> {
        let required = ["title", "url", "collectionName", "collectionURL", "domOrder"]
        let optional = ["visibleDateText"]
        return checked(body, required: required, optional: optional).flatMap { dict in
            do {
                return .success(ImporterChapterPayload(
                    title: try string(dict, "title", max: maxFieldLength),
                    url: try string(dict, "url", max: maxURLLength),
                    visibleDateText: try optionalString(dict, "visibleDateText", max: maxFieldLength),
                    collectionName: try string(dict, "collectionName", max: maxFieldLength),
                    collectionURL: try string(dict, "collectionURL", max: maxURLLength),
                    domOrder: try int(dict, "domOrder")))
            } catch let e as PayloadError { return .failure(e) } catch { return .failure(.notADictionary) }
        }
    }

    public static func validateCollectionLink(_ body: Any) -> Result<CollectionLinkPayload, PayloadError> {
        return checked(body, required: ["collectionName", "collectionURL"], optional: []).flatMap { dict in
            do {
                return .success(CollectionLinkPayload(
                    collectionName: try string(dict, "collectionName", max: maxFieldLength),
                    collectionURL: try string(dict, "collectionURL", max: maxURLLength)))
            } catch let e as PayloadError { return .failure(e) } catch { return .failure(.notADictionary) }
        }
    }

    public static func validateProgress(_ body: Any) -> Result<ProgressPayload, PayloadError> {
        return checked(body, required: ["url", "scrollProgress"], optional: []).flatMap { dict in
            do {
                let url = try string(dict, "url", max: maxURLLength)
                guard let raw = dict["scrollProgress"] as? Double ?? (dict["scrollProgress"] as? Int).map(Double.init)
                else { return .failure(.wrongType("scrollProgress")) }
                return .success(ProgressPayload(url: url, scrollProgress: min(1.0, max(0.0, raw))))
            } catch let e as PayloadError { return .failure(e) } catch { return .failure(.notADictionary) }
        }
    }

    // MARK: shared checks

    private static func checked(_ body: Any, required: [String], optional: [String])
        -> Result<[String: Any], PayloadError> {
        guard let dict = body as? [String: Any] else { return .failure(.notADictionary) }
        if let data = try? JSONSerialization.data(withJSONObject: dict), data.count > maxMessageBytes {
            return .failure(.tooLarge("message"))
        }
        let allowed = Set(required + optional)
        for key in dict.keys {
            if forbiddenKeys.contains(key.lowercased()) { return .failure(.forbiddenKey(key.lowercased())) }
        }
        for key in dict.keys where !allowed.contains(key) {
            return .failure(.unknownKey(key))
        }
        for key in required where dict[key] == nil || dict[key] is NSNull {
            return .failure(.missingKey(key))
        }
        return .success(dict)
    }

    private static func string(_ dict: [String: Any], _ key: String, max: Int) throws -> String {
        guard let value = dict[key] as? String else { throw PayloadError.wrongType(key) }
        guard value.utf8.count <= max else { throw PayloadError.tooLarge(key) }
        return value
    }

    private static func optionalString(_ dict: [String: Any], _ key: String, max: Int) throws -> String? {
        guard let raw = dict[key], !(raw is NSNull) else { return nil }
        return try string(dict, key, max: max)
    }

    private static func int(_ dict: [String: Any], _ key: String) throws -> Int {
        guard let value = dict[key] as? Int else { throw PayloadError.wrongType(key) }
        return value
    }
}
```

- [ ] **Step 5: Run tests, verify pass**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add ChapterlyCore
git commit -m "Add strict payload validator as content firewall"
```

---

### Task 4: ChapterMapMerger

Spec §3.3 steps 5–8: merge-by-URL, preserve manual edits, DOM order base, dedupe.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/ChapterMapMerger.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/ChapterMapMergerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import ChapterlyCore

final class ChapterMapMergerTests: XCTestCase {
    private func payload(_ title: String, _ url: String, order: Int) -> ImporterChapterPayload {
        ImporterChapterPayload(title: title, url: url, visibleDateText: nil,
                               collectionName: "焚心", collectionURL: "https://www.patreon.com/collection/9",
                               domOrder: order)
    }

    func testFreshImportUsesDomOrder() {
        let merged = ChapterMapMerger.merge(existing: [], incoming: [
            payload("4 愛", "https://patreon.com/posts/4-2", order: 1),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 2),
            payload("3", "https://patreon.com/posts/3-1", order: 0)
        ])
        XCTAssertEqual(merged.map(\.title), ["3", "4 愛", "5 脣瓣"])
        XCTAssertEqual(merged.map(\.orderIndex), [0, 1, 2])
        XCTAssertEqual(merged[0].urlString, "https://www.patreon.com/posts/3-1")
    }

    func testReimportPreservesManualEditsAndAppendsNew() {
        let existing = [
            ChapterRecord(title: "My renamed title", urlString: "https://www.patreon.com/posts/3-1",
                          visibleDateText: nil, orderIndex: 0),
            ChapterRecord(title: "4 愛", urlString: "https://www.patreon.com/posts/4-2",
                          visibleDateText: nil, orderIndex: 1)
        ]
        let merged = ChapterMapMerger.merge(existing: existing, incoming: [
            payload("3", "https://patreon.com/posts/3-1?utm_source=x", order: 0),
            payload("4 愛", "https://patreon.com/posts/4-2", order: 1),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 2)
        ])
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged[0].title, "My renamed title") // manual rename preserved
        XCTAssertEqual(merged[2].title, "5 脣瓣")
        XCTAssertEqual(merged[2].orderIndex, 2)
    }

    func testDuplicateURLsWithinImportDeduped() {
        let merged = ChapterMapMerger.merge(existing: [], incoming: [
            payload("A", "https://patreon.com/posts/a-1", order: 0),
            payload("A again", "https://patreon.com/posts/a-1/", order: 1)
        ])
        XCTAssertEqual(merged.count, 1)
    }

    func testUnnormalizableURLSkipped() {
        let merged = ChapterMapMerger.merge(existing: [], incoming: [
            payload("evil", "https://example.com/posts/x", order: 0),
            payload("ok", "https://patreon.com/posts/ok-1", order: 1)
        ])
        XCTAssertEqual(merged.map(\.title), ["ok"])
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --package-path ChapterlyCore`
Expected: FAIL — `cannot find 'ChapterMapMerger'` / `'ChapterRecord'`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Pure value used by merge logic; the SwiftData layer maps to/from it.
public struct ChapterRecord: Equatable {
    public var title: String
    public var urlString: String        // always normalized
    public var visibleDateText: String?
    public var orderIndex: Int

    public init(title: String, urlString: String, visibleDateText: String?, orderIndex: Int) {
        self.title = title
        self.urlString = urlString
        self.visibleDateText = visibleDateText
        self.orderIndex = orderIndex
    }
}

/// Merge-by-URL (spec §3.3 step 5): existing entries are never overwritten
/// (manual renames/reorders survive re-import); new chapters append in DOM order.
public enum ChapterMapMerger {
    public static func merge(existing: [ChapterRecord],
                             incoming: [ImporterChapterPayload]) -> [ChapterRecord] {
        var result = existing
        var known = Set(existing.map(\.urlString))
        var nextIndex = (existing.map(\.orderIndex).max() ?? -1) + 1

        for candidate in incoming.sorted(by: { $0.domOrder < $1.domOrder }) {
            guard let normalized = URLNormalizer.normalize(candidate.url)?.absoluteString,
                  !known.contains(normalized) else { continue }
            known.insert(normalized)
            result.append(ChapterRecord(title: candidate.title,
                                        urlString: normalized,
                                        visibleDateText: candidate.visibleDateText,
                                        orderIndex: nextIndex))
            nextIndex += 1
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add ChapterlyCore
git commit -m "Add chapter map merger with manual-edit preservation"
```

---

### Task 5: NavigationPolicy

Spec §3.1: top-level navigation stays on Patreon hosts; everything else opens in Safari. Pure function so it's trivially testable; the WKNavigationDelegate just calls it.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/NavigationPolicy.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/NavigationPolicyTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import ChapterlyCore

final class NavigationPolicyTests: XCTestCase {
    func testPatreonMainFrameAllowed() {
        for s in ["https://www.patreon.com/home",
                  "https://patreon.com/posts/x-1",
                  "https://auth.patreon.com/login"] {
            XCTAssertEqual(NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true),
                           .allowInWebView, s)
        }
    }

    func testExternalMainFrameOpensSafari() {
        for s in ["https://example.com", "https://twitter.com/someone", "https://patreon.com.evil.com/x"] {
            XCTAssertEqual(NavigationPolicy.decide(url: URL(string: s)!, isMainFrame: true),
                           .openInSafari, s)
        }
    }

    func testSubframesAlwaysAllowed() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "https://cdn.example.com/img.png")!,
                                               isMainFrame: false),
                       .allowInWebView)
    }

    func testNonHTTPSchemesBlocked() {
        XCTAssertEqual(NavigationPolicy.decide(url: URL(string: "ftp://patreon.com/x")!, isMainFrame: true),
                       .block)
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --package-path ChapterlyCore`
Expected: FAIL — `cannot find 'NavigationPolicy'`.

- [ ] **Step 3: Implement**

```swift
import Foundation

public enum NavigationDecision: Equatable {
    case allowInWebView
    case openInSafari
    case block
}

/// Spec §3.1: top-level navigation only on patreon.com and its subdomains.
/// Subresources/subframes are Patreon's own page internals — always allowed.
public enum NavigationPolicy {
    public static func decide(url: URL, isMainFrame: Bool) -> NavigationDecision {
        guard isMainFrame else { return .allowInWebView }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return .block
        }
        guard let host = url.host?.lowercased() else { return .block }
        if host == "patreon.com" || host.hasSuffix(".patreon.com") {
            return .allowInWebView
        }
        return .openInSafari
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add ChapterlyCore
git commit -m "Add top-level navigation policy"
```

---

### Task 6: SwiftData models and LibraryStore

Spec §3.4. `@Model` classes with cascade relationship, explicit `orderIndex`. URLs stored as normalized strings (predicate matching on strings; the spec's `URL` type is realized as a normalized string column).

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/Models.swift`
- Create: `ChapterlyCore/Sources/ChapterlyCore/LibraryStore.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/LibraryStoreTests.swift`

- [ ] **Step 1: Write models**

`Models.swift`:
```swift
import Foundation
import SwiftData

public enum CollectionSortDirection: String, Codable {
    case oldestToNewest
    case newestToOldest
}

@Model
public final class LocalCollectionModel {
    @Attribute(.unique) public var id: String
    public var title: String
    public var sourceURLString: String        // normalized
    public var creatorName: String?
    public var sortDirectionRaw: String
    @Relationship(deleteRule: .cascade, inverse: \LocalChapterModel.collection)
    public var chapters: [LocalChapterModel]

    public var sortDirection: CollectionSortDirection {
        get { CollectionSortDirection(rawValue: sortDirectionRaw) ?? .oldestToNewest }
        set { sortDirectionRaw = newValue.rawValue }
    }

    public init(id: String = UUID().uuidString,
                title: String,
                sourceURLString: String,
                creatorName: String? = nil,
                sortDirection: CollectionSortDirection = .oldestToNewest) {
        self.id = id
        self.title = title
        self.sourceURLString = sourceURLString
        self.creatorName = creatorName
        self.sortDirectionRaw = sortDirection.rawValue
        self.chapters = []
    }
}

@Model
public final class LocalChapterModel {
    @Attribute(.unique) public var id: String
    public var title: String
    public var urlString: String              // normalized
    public var orderIndex: Int                // explicit, never derived at query time
    public var visibleDateText: String?
    public var readingProgress: Double?
    public var lastReadAt: Date?
    public var collection: LocalCollectionModel?

    public init(id: String = UUID().uuidString,
                title: String,
                urlString: String,
                orderIndex: Int,
                visibleDateText: String? = nil) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.orderIndex = orderIndex
        self.visibleDateText = visibleDateText
    }
}
```

- [ ] **Step 2: Write the failing store tests**

```swift
import XCTest
import SwiftData
@testable import ChapterlyCore

@MainActor
final class LibraryStoreTests: XCTestCase {
    private var store: LibraryStore!

    override func setUp() async throws {
        store = try LibraryStore.inMemory()
    }

    private func payload(_ title: String, _ url: String, order: Int) -> ImporterChapterPayload {
        ImporterChapterPayload(title: title, url: url, visibleDateText: nil,
                               collectionName: "【更新中】焚心 The Burning Heart",
                               collectionURL: "https://www.patreon.com/collection/9999",
                               domOrder: order)
    }

    func testImportCreatesCollectionAndChapters() throws {
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let collections = try store.collections()
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections[0].title, "【更新中】焚心 The Burning Heart")
        XCTAssertEqual(store.orderedChapters(of: collections[0]).map(\.title), ["4 愛", "5 脣瓣"])
    }

    func testReimportMergesWithoutDuplicates() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.applyImport([
            payload("4 愛", "https://patreon.com/posts/4-2/", order: 0),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 1)
        ])
        let chapters = store.orderedChapters(of: try store.collections()[0])
        XCTAssertEqual(chapters.map(\.title), ["4 愛", "5 脣瓣"])
    }

    func testReverseDirectionFlipsReadingOrder() throws {
        try store.applyImport([
            payload("newest", "https://patreon.com/posts/n-3", order: 0),
            payload("oldest", "https://patreon.com/posts/o-1", order: 1)
        ])
        let collection = try store.collections()[0]
        collection.sortDirection = .newestToOldest
        XCTAssertEqual(store.orderedChapters(of: collection).map(\.title), ["oldest", "newest"])
    }

    func testNeighborsFollowReadingOrder() throws {
        try store.applyImport([
            payload("3", "https://patreon.com/posts/3-1", order: 0),
            payload("4 愛", "https://patreon.com/posts/4-2", order: 1),
            payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 2)
        ])
        let collection = try store.collections()[0]
        let middle = store.orderedChapters(of: collection)[1]
        let n = store.neighbors(of: middle)
        XCTAssertEqual(n.previous?.title, "3")
        XCTAssertEqual(n.next?.title, "5 脣瓣")
    }

    func testProgressSavedByNormalizedURL() throws {
        try store.applyImport([payload("5 脣瓣", "https://patreon.com/posts/5-3", order: 0)])
        store.setProgress(forPageURL: "https://www.patreon.com/posts/5-3?utm_source=share", progress: 0.6)
        let chapter = store.chapter(withPageURL: "https://patreon.com/posts/5-3/")
        XCTAssertEqual(chapter?.readingProgress ?? -1, 0.6, accuracy: 0.001)
        XCTAssertNotNil(chapter?.lastReadAt)
    }

    func testManualAddRenameDelete() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let collection = try store.collections()[0]
        try store.addManualChapter(to: collection, title: "Extra",
                                   urlString: "https://patreon.com/posts/extra-9")
        var chapters = store.orderedChapters(of: collection)
        XCTAssertEqual(chapters.count, 2)
        store.rename(chapters[1], to: "Extra (fixed)")
        store.delete(chapters[0])
        chapters = store.orderedChapters(of: collection)
        XCTAssertEqual(chapters.map(\.title), ["Extra (fixed)"])
    }

    func testClearLibraryRemovesEverything() throws {
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        try store.clearLibrary()
        XCTAssertTrue(try store.collections().isEmpty)
    }

    func testNoChapterStoresBodyText() throws {
        // Belt-and-braces: the model has no field that could hold a body;
        // assert schema-level — every persisted string is short metadata.
        try store.applyImport([payload("4 愛", "https://patreon.com/posts/4-2", order: 0)])
        let chapter = store.orderedChapters(of: try store.collections()[0])[0]
        XCTAssertLessThan(chapter.title.utf8.count, PayloadValidator.maxFieldLength + 1)
        XCTAssertLessThan(chapter.urlString.utf8.count, PayloadValidator.maxURLLength + 1)
    }
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `swift test --package-path ChapterlyCore`
Expected: FAIL — `cannot find 'LibraryStore'`.

- [ ] **Step 4: Implement LibraryStore**

`LibraryStore.swift`:
```swift
import Foundation
import SwiftData

/// All persistence goes through this store. Stores metadata only (spec §3.4).
@MainActor
public final class LibraryStore {
    public let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    public static func inMemory() throws -> LibraryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalCollectionModel.self, LocalChapterModel.self,
                                           configurations: config)
        return LibraryStore(container: container)
    }

    public static func onDisk() throws -> LibraryStore {
        let container = try ModelContainer(for: LocalCollectionModel.self, LocalChapterModel.self)
        return LibraryStore(container: container)
    }

    // MARK: import

    /// Validated importer payloads → upsert collection + merge chapters.
    public func applyImport(_ payloads: [ImporterChapterPayload]) throws {
        guard let first = payloads.first,
              let collectionURL = URLNormalizer.normalize(first.collectionURL)?.absoluteString
        else { return }

        let collection = try findCollection(sourceURLString: collectionURL)
            ?? {
                let c = LocalCollectionModel(title: first.collectionName, sourceURLString: collectionURL)
                context.insert(c)
                return c
            }()

        let existing = collection.chapters
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { ChapterRecord(title: $0.title, urlString: $0.urlString,
                                 visibleDateText: $0.visibleDateText, orderIndex: $0.orderIndex) }
        let merged = ChapterMapMerger.merge(existing: existing, incoming: payloads)

        let knownURLs = Set(collection.chapters.map(\.urlString))
        for record in merged where !knownURLs.contains(record.urlString) {
            let chapter = LocalChapterModel(title: record.title, urlString: record.urlString,
                                            orderIndex: record.orderIndex,
                                            visibleDateText: record.visibleDateText)
            chapter.collection = collection
            context.insert(chapter)
        }
        try context.save()
    }

    // MARK: queries

    public func collections() throws -> [LocalCollectionModel] {
        try context.fetch(FetchDescriptor<LocalCollectionModel>(
            sortBy: [SortDescriptor(\.title)]))
    }

    /// Reading order: orderIndex ascending; reversed when newestToOldest.
    public func orderedChapters(of collection: LocalCollectionModel) -> [LocalChapterModel] {
        let asc = collection.chapters.sorted { $0.orderIndex < $1.orderIndex }
        return collection.sortDirection == .oldestToNewest ? asc : asc.reversed()
    }

    public func neighbors(of chapter: LocalChapterModel)
        -> (previous: LocalChapterModel?, next: LocalChapterModel?) {
        guard let collection = chapter.collection else { return (nil, nil) }
        let ordered = orderedChapters(of: collection)
        guard let i = ordered.firstIndex(where: { $0.id == chapter.id }) else { return (nil, nil) }
        return (i > 0 ? ordered[i - 1] : nil,
                i < ordered.count - 1 ? ordered[i + 1] : nil)
    }

    public func chapter(withPageURL pageURL: String) -> LocalChapterModel? {
        guard let normalized = URLNormalizer.normalize(pageURL)?.absoluteString else { return nil }
        var descriptor = FetchDescriptor<LocalChapterModel>(
            predicate: #Predicate { $0.urlString == normalized })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: edits

    public func setProgress(forPageURL pageURL: String, progress: Double) {
        guard let chapter = chapter(withPageURL: pageURL) else { return }
        chapter.readingProgress = min(1.0, max(0.0, progress))
        chapter.lastReadAt = Date()
        try? context.save()
    }

    public func rename(_ chapter: LocalChapterModel, to title: String) {
        chapter.title = String(title.prefix(PayloadValidator.maxFieldLength))
        try? context.save()
    }

    public func delete(_ chapter: LocalChapterModel) {
        context.delete(chapter)
        try? context.save()
    }

    public func deleteCollection(_ collection: LocalCollectionModel) {
        context.delete(collection)   // cascade deletes chapters
        try? context.save()
    }

    public func addManualChapter(to collection: LocalCollectionModel,
                                 title: String, urlString: String) throws {
        guard let normalized = URLNormalizer.normalize(urlString)?.absoluteString else { return }
        guard !collection.chapters.contains(where: { $0.urlString == normalized }) else { return }
        let nextIndex = (collection.chapters.map(\.orderIndex).max() ?? -1) + 1
        let chapter = LocalChapterModel(title: title, urlString: normalized, orderIndex: nextIndex)
        chapter.collection = collection
        context.insert(chapter)
        try context.save()
    }

    public func moveChapters(in collection: LocalCollectionModel, from source: IndexSet, to destination: Int) {
        var ordered = orderedChapters(of: collection)
        ordered.move(fromOffsets: source, toOffset: destination)
        // Re-number in display order; if reversed, flip back so orderIndex stays canonical-ascending.
        let canonical = collection.sortDirection == .oldestToNewest ? ordered : ordered.reversed()
        for (i, chapter) in canonical.enumerated() { chapter.orderIndex = i }
        try? context.save()
    }

    // MARK: clearing (spec §3.5 — library only; webview store handled elsewhere)

    public func clearLibrary() throws {
        for collection in try collections() { context.delete(collection) }
        try context.save()
    }
}
```

- [ ] **Step 5: Run tests, verify pass**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add ChapterlyCore
git commit -m "Add SwiftData models and LibraryStore"
```

---

### Task 7: JS assets + metadata-only extraction proof

Spec §3.3 and §6. JS lives as bundled package resources. Fixture HTML includes fake body text; tests load fixtures into a real WKWebView (macOS, off-screen) and assert only metadata comes back.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/Assets/CollectionImport.js`
- Create: `ChapterlyCore/Sources/ChapterlyCore/Assets/CollectionDetect.js`
- Create: `ChapterlyCore/Sources/ChapterlyCore/Assets/ProgressTracker.js`
- Create: `ChapterlyCore/Sources/ChapterlyCore/JSAssets.swift`
- Create: `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/collection_page.html`
- Create: `ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/post_page.html`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/JSExtractionTests.swift`
- Delete: both `.gitkeep` files from Task 1

- [ ] **Step 1: Write fixtures (sanitized structure, fake bodies — spec §6)**

`collection_page.html`:
```html
<!DOCTYPE html>
<html>
<head><title>【更新中】焚心 The Burning Heart | Patreon</title></head>
<body>
  <h1>【更新中】焚心 The Burning Heart</h1>
  <main>
    <article>
      <p id="fake-body-1">FAKE_BODY_TEXT_MUST_NEVER_LEAK lorem fake paragraph.</p>
      <a href="https://www.patreon.com/posts/3-111?utm_source=collection">3 試探</a>
      <a href="https://www.patreon.com/posts/4-222">4 愛</a>
      <a href="https://www.patreon.com/posts/5-333/">5 脣瓣</a>
      <a href="https://www.patreon.com/posts/6-444">6 浴室的紅櫻桃(R18+)</a>
      <a href="https://www.patreon.com/posts/4-222">4 愛 (duplicate link)</a>
      <a href="https://example.com/posts/evil">external decoy</a>
    </article>
  </main>
</body>
</html>
```

`post_page.html`:
```html
<!DOCTYPE html>
<html>
<head><title>5 脣瓣 | Patreon</title></head>
<body>
  <h1>5 脣瓣</h1>
  <div id="fake-body">FAKE_BODY_TEXT_MUST_NEVER_LEAK chapter prose goes here.</div>
  <div>於作品系列中：<a href="https://www.patreon.com/collection/9999">【更新中】焚心 The Burning Heart</a></div>
</body>
</html>
```

- [ ] **Step 2: Write the JS assets**

`CollectionImport.js` — reads only anchors visible in the loaded DOM; one flat message per chapter; never touches body text:
```javascript
(function () {
  "use strict";
  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.chapterlyImport;
  if (!handler) { return; }

  var h1 = document.querySelector("h1");
  var collectionName = ((h1 && h1.textContent) || document.title || "").trim().slice(0, 512);
  var collectionURL = location.href;

  var seen = {};
  var order = 0;
  var anchors = document.querySelectorAll('a[href*="/posts/"]');
  for (var i = 0; i < anchors.length; i++) {
    var a = anchors[i];
    var href = a.href || "";
    if (!href || seen[href]) { continue; }
    var title = (a.textContent || "").trim().slice(0, 512);
    if (!title) { continue; }
    seen[href] = true;
    handler.postMessage({
      title: title,
      url: href,
      visibleDateText: null,
      collectionName: collectionName,
      collectionURL: collectionURL,
      domOrder: order
    });
    order += 1;
  }
})();
```

`CollectionDetect.js` — run on post pages to find a visible collection link:
```javascript
(function () {
  "use strict";
  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.chapterlyCollectionLink;
  if (!handler) { return; }
  var a = document.querySelector('a[href*="/collection/"]');
  if (!a) { return; }
  handler.postMessage({
    collectionName: (a.textContent || "").trim().slice(0, 512),
    collectionURL: a.href
  });
})();
```

`ProgressTracker.js` — throttled scroll percentage; url + number only:
```javascript
(function () {
  "use strict";
  if (window.__chapterlyProgressInstalled) { return; }
  window.__chapterlyProgressInstalled = true;
  var handler = window.webkit && window.webkit.messageHandlers
    && window.webkit.messageHandlers.chapterlyProgress;
  if (!handler) { return; }
  var pending = null;
  window.addEventListener("scroll", function () {
    if (pending) { return; }
    pending = setTimeout(function () {
      pending = null;
      var doc = document.documentElement;
      var max = doc.scrollHeight - window.innerHeight;
      var p = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
      handler.postMessage({ url: location.href, scrollProgress: p });
    }, 500);
  }, { passive: true });
})();
```

- [ ] **Step 3: Write the asset loader**

`JSAssets.swift`:
```swift
import Foundation

public enum JSAssets {
    public static func script(named name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing bundled script \(name).js")
            return ""
        }
        return source
    }

    public static var collectionImport: String { script(named: "CollectionImport") }
    public static var collectionDetect: String { script(named: "CollectionDetect") }
    public static var progressTracker: String { script(named: "ProgressTracker") }
}
```

- [ ] **Step 4: Write the failing extraction tests**

`JSExtractionTests.swift` — loads fixture HTML in an off-screen WKWebView, runs the import script, collects messages. The metadata-only proof: assert `FAKE_BODY_TEXT_MUST_NEVER_LEAK` never appears in any message and all payloads pass the validator.

```swift
import XCTest
import WebKit
@testable import ChapterlyCore

@MainActor
final class JSExtractionTests: XCTestCase {

    final class Collector: NSObject, WKScriptMessageHandler {
        var bodies: [Any] = []
        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            bodies.append(message.body)
        }
    }

    private func runScript(_ script: String, fixture: String, handlerName: String) async throws -> [Any] {
        let collector = Collector()
        let config = WKWebViewConfiguration()
        config.userContentController.add(collector, name: handlerName)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: config)
        let url = Bundle.module.url(forResource: fixture, withExtension: "html")!
        let html = try String(contentsOf: url, encoding: .utf8)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.patreon.com/")!)

        // Wait for load
        for _ in 0..<100 {
            if !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        _ = try? await webView.evaluateJavaScript(script)
        try await Task.sleep(for: .milliseconds(200))
        return collector.bodies
    }

    func testCollectionImportExtractsMetadataOnly() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page",
                                         handlerName: "chapterlyImport")
        XCTAssertEqual(bodies.count, 5) // 4 unique patreon posts + 1 external decoy (validator-independent JS count)

        var payloads: [ImporterChapterPayload] = []
        for body in bodies {
            // Every message must survive the strict validator.
            payloads.append(try PayloadValidator.validateImporterChapter(body).get())
        }
        // Body text never leaks into any field of any message.
        let allText = payloads.flatMap { [$0.title, $0.url, $0.collectionName, $0.collectionURL,
                                          $0.visibleDateText ?? ""] }.joined()
        XCTAssertFalse(allText.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
        XCTAssertFalse(allText.contains("<"))

        XCTAssertEqual(payloads[0].title, "3 試探")
        XCTAssertEqual(payloads[0].domOrder, 0)
        XCTAssertEqual(payloads.map(\.title).filter { $0.contains("愛") }.count, 1) // dedupe by href
        XCTAssertTrue(payloads.allSatisfy { $0.collectionName == "【更新中】焚心 The Burning Heart" })
    }

    func testExternalDecoySkippedAfterNormalization() async throws {
        let bodies = try await runScript(JSAssets.collectionImport,
                                         fixture: "collection_page",
                                         handlerName: "chapterlyImport")
        let payloads = bodies.compactMap { try? PayloadValidator.validateImporterChapter($0).get() }
        let merged = ChapterMapMerger.merge(existing: [], incoming: payloads)
        XCTAssertEqual(merged.count, 4) // example.com decoy dropped by URLNormalizer
        XCTAssertEqual(merged.map(\.title), ["3 試探", "4 愛", "5 脣瓣", "6 浴室的紅櫻桃(R18+)"])
    }

    func testCollectionDetectFindsSeriesLink() async throws {
        let bodies = try await runScript(JSAssets.collectionDetect,
                                         fixture: "post_page",
                                         handlerName: "chapterlyCollectionLink")
        XCTAssertEqual(bodies.count, 1)
        let p = try PayloadValidator.validateCollectionLink(bodies[0]).get()
        XCTAssertEqual(p.collectionName, "【更新中】焚心 The Burning Heart")
        XCTAssertEqual(URLNormalizer.normalize(p.collectionURL)?.absoluteString,
                       "https://www.patreon.com/collection/9999")
        XCTAssertFalse(p.collectionName.contains("FAKE_BODY_TEXT_MUST_NEVER_LEAK"))
    }
}
```

Note: if WKWebView proves flaky under headless `swift test` on this machine, move this one test file into the app's test target in Task 12 and run it in the simulator instead. Do not delete the assertions.

- [ ] **Step 5: Run tests**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS (first run of JS tests fails until Steps 1–3 files exist; order of steps above ensures they do).

- [ ] **Step 6: Commit**

```bash
git add -A ChapterlyCore
git commit -m "Add JS assets with metadata-only extraction proof tests"
```

---

### Task 8: ScriptMessageRouter

Glue: WKScriptMessageHandler → PayloadValidator → typed callbacks. Validation failures are counted, never logged with contents.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/ScriptMessageRouter.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/ScriptMessageRouterTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import ChapterlyCore

final class ScriptMessageRouterTests: XCTestCase {
    func testRoutesValidImporterMessage() {
        var received: [ImporterChapterPayload] = []
        let router = ScriptMessageRouter()
        router.onImporterChapter = { received.append($0) }
        router.route(name: ScriptMessageRouter.importName, body: [
            "title": "4 愛", "url": "https://patreon.com/posts/4-2",
            "visibleDateText": NSNull(),
            "collectionName": "焚心", "collectionURL": "https://patreon.com/collection/9",
            "domOrder": 0
        ] as [String: Any])
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(router.rejectedCount, 0)
    }

    func testRejectsAndCountsForbiddenPayload() {
        var received: [ImporterChapterPayload] = []
        let router = ScriptMessageRouter()
        router.onImporterChapter = { received.append($0) }
        router.route(name: ScriptMessageRouter.importName, body: [
            "title": "x", "url": "https://patreon.com/posts/x",
            "collectionName": "c", "collectionURL": "https://patreon.com/collection/9",
            "domOrder": 0, "innerHTML": "<p>steal</p>"
        ] as [String: Any])
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(router.rejectedCount, 1)
    }

    func testRoutesProgressAndCollectionLink() {
        var progress: [ProgressPayload] = []
        var links: [CollectionLinkPayload] = []
        let router = ScriptMessageRouter()
        router.onProgress = { progress.append($0) }
        router.onCollectionLink = { links.append($0) }
        router.route(name: ScriptMessageRouter.progressName,
                     body: ["url": "https://patreon.com/posts/x", "scrollProgress": 0.3] as [String: Any])
        router.route(name: ScriptMessageRouter.collectionLinkName,
                     body: ["collectionName": "焚心",
                            "collectionURL": "https://patreon.com/collection/9"] as [String: Any])
        XCTAssertEqual(progress.count, 1)
        XCTAssertEqual(links.count, 1)
    }

    func testUnknownHandlerNameIgnored() {
        let router = ScriptMessageRouter()
        router.route(name: "somethingElse", body: ["a": 1])
        XCTAssertEqual(router.rejectedCount, 1)
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --package-path ChapterlyCore`
Expected: FAIL — `cannot find 'ScriptMessageRouter'`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Routes raw script-message bodies through PayloadValidator to typed callbacks.
/// Pure logic — the WKScriptMessageHandler shim in the app calls `route`.
public final class ScriptMessageRouter {
    public static let importName = "chapterlyImport"
    public static let collectionLinkName = "chapterlyCollectionLink"
    public static let progressName = "chapterlyProgress"

    public static var allHandlerNames: [String] { [importName, collectionLinkName, progressName] }

    public var onImporterChapter: ((ImporterChapterPayload) -> Void)?
    public var onCollectionLink: ((CollectionLinkPayload) -> Void)?
    public var onProgress: ((ProgressPayload) -> Void)?

    /// Count only — payload contents are never logged (spec §3.3).
    public private(set) var rejectedCount = 0

    public init() {}

    public func route(name: String, body: Any) {
        switch name {
        case Self.importName:
            deliver(PayloadValidator.validateImporterChapter(body), to: onImporterChapter)
        case Self.collectionLinkName:
            deliver(PayloadValidator.validateCollectionLink(body), to: onCollectionLink)
        case Self.progressName:
            deliver(PayloadValidator.validateProgress(body), to: onProgress)
        default:
            rejectedCount += 1
        }
    }

    private func deliver<T>(_ result: Result<T, PayloadError>, to callback: ((T) -> Void)?) {
        switch result {
        case .success(let payload): callback?(payload)
        case .failure: rejectedCount += 1
        }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add ChapterlyCore
git commit -m "Add script message router with rejection counting"
```

---

### Task 9: ReaderStyler CSS ruleset + injection builder

Spec §3.2. The ruleset is a bundled, human-editable CSS file. Swift wraps it into an injectable script with a font-size CSS variable. Selectors WILL rot when Patreon changes markup — that is why they live in one file; failure mode is the plain page.

**Files:**
- Create: `ChapterlyCore/Sources/ChapterlyCore/Assets/ReaderRuleset.css`
- Create: `ChapterlyCore/Sources/ChapterlyCore/ReaderStyler.swift`
- Test: `ChapterlyCore/Tests/ChapterlyCoreTests/ReaderStylerTests.swift`

- [ ] **Step 1: Write the CSS ruleset**

`ReaderRuleset.css`:
```css
/* Chapterly reader ruleset.
   Edit selectors here when Patreon markup changes — no rebuild needed beyond
   re-bundling. If selectors stop matching, the page simply renders as plain
   Patreon (graceful degradation, spec §3.2). */

/* --- hide chrome --- */
nav,
aside,
footer,
[data-tag="post-actions"],
[data-tag="comment-row"],
[data-tag="comment-field"],
[data-tag="creator-header"],
[aria-label="Search"],
div[class*="sidebar"] {
  display: none !important;
}

/* --- reading column --- */
[data-tag="post-content"],
article {
  max-width: 42em !important;
  margin-left: auto !important;
  margin-right: auto !important;
  font-family: Georgia, "Noto Serif TC", "Songti TC", serif !important;
  font-size: var(--chapterly-font-size, 19px) !important;
  line-height: 1.75 !important;
}

[data-tag="post-title"],
article h1 {
  font-family: Georgia, "Noto Serif TC", serif !important;
  line-height: 1.3 !important;
}

body {
  background-color: #faf8f5 !important;
}

@media (prefers-color-scheme: dark) {
  body { background-color: #1c1b19 !important; }
}
```

- [ ] **Step 2: Write the failing tests**

```swift
import XCTest
@testable import ChapterlyCore

final class ReaderStylerTests: XCTestCase {
    func testInjectionScriptEmbedsRulesetAndStyleId() {
        let js = ReaderStyler.injectionScript()
        XCTAssertTrue(js.contains(ReaderStyler.styleElementID))
        XCTAssertTrue(js.contains("--chapterly-font-size"))
        XCTAssertTrue(js.contains("data-tag")) // ruleset content embedded
    }

    func testRemovalScriptTargetsSameId() {
        XCTAssertTrue(ReaderStyler.removalScript().contains(ReaderStyler.styleElementID))
    }

    func testFontSizeScriptSetsVariable() {
        let js = ReaderStyler.fontSizeScript(points: 21)
        XCTAssertTrue(js.contains("--chapterly-font-size"))
        XCTAssertTrue(js.contains("21px"))
    }

    func testRulesetEscapedForTemplateLiteral() {
        // Backticks or ${ in CSS would break the JS template literal.
        XCTAssertFalse(ReaderStyler.ruleset().contains("`"))
        XCTAssertFalse(ReaderStyler.ruleset().contains("${"))
    }
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `swift test --package-path ChapterlyCore`
Expected: FAIL — `cannot find 'ReaderStyler'`.

- [ ] **Step 4: Implement**

```swift
import Foundation

/// Builds the reader-mode injection scripts from the bundled CSS ruleset (spec §3.2).
public enum ReaderStyler {
    public static let styleElementID = "chapterly-reader-style"

    public static func ruleset() -> String {
        guard let url = Bundle.module.url(forResource: "ReaderRuleset", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing ReaderRuleset.css")
            return ""
        }
        return css
    }

    /// Idempotent: replaces any existing style element.
    public static func injectionScript() -> String {
        let css = ruleset()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return """
        (function () {
          var old = document.getElementById("\(styleElementID)");
          if (old) { old.remove(); }
          var style = document.createElement("style");
          style.id = "\(styleElementID)";
          style.textContent = `\(css)`;
          document.documentElement.appendChild(style);
        })();
        """
    }

    public static func removalScript() -> String {
        """
        (function () {
          var old = document.getElementById("\(styleElementID)");
          if (old) { old.remove(); }
        })();
        """
    }

    public static func fontSizeScript(points: Int) -> String {
        let clamped = min(32, max(14, points))
        return "document.documentElement.style.setProperty('--chapterly-font-size', '\(clamped)px');"
    }

    public static func restoreScrollScript(progress: Double) -> String {
        let clamped = min(1.0, max(0.0, progress))
        return """
        (function () {
          var doc = document.documentElement;
          var max = doc.scrollHeight - window.innerHeight;
          if (max > 0) { window.scrollTo(0, max * \(clamped)); }
        })();
        """
    }
}
```

- [ ] **Step 5: Run tests, verify pass**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add ChapterlyCore
git commit -m "Add reader styler with editable CSS ruleset"
```

---

### Task 10: WebView container + app environment

App-side WKWebView wrapper wiring everything: navigation policy, message router, user scripts. One shared `AppEnvironment` owns the store and the two webview models (Browse, Reader) so the Patreon session is shared via the default `WKWebsiteDataStore`.

**Files:**
- Create: `App/WebView/PatreonWebView.swift`
- Create: `App/WebView/WebViewModel.swift`
- Create: `App/AppEnvironment.swift`
- Modify: `App/AppRootView.swift`

No new unit tests here — all decision logic was tested in Tasks 5 and 8; this task is assembly. Verification is a build + manual smoke in Task 14.

- [ ] **Step 1: Write WebViewModel**

`App/WebView/WebViewModel.swift`:
```swift
import Foundation
import WebKit
import ChapterlyCore

@MainActor
@Observable
final class WebViewModel: NSObject {
    let webView: WKWebView
    let router = ScriptMessageRouter()
    var currentURL: URL?
    var detectedCollection: CollectionLinkPayload?
    var isOnCollectionPage: Bool {
        guard let url = currentURL else { return false }
        return url.path.contains("/collection/")
    }

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // session lives here; never read, only wiped
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        for name in ScriptMessageRouter.allHandlerNames {
            config.userContentController.add(MessageShim(router: router), name: name)
        }
        config.userContentController.addUserScript(WKUserScript(
            source: JSAssets.progressTracker,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func runCollectionDetect() {
        webView.evaluateJavaScript(JSAssets.collectionDetect, completionHandler: nil)
    }

    func runCollectionImport() {
        webView.evaluateJavaScript(JSAssets.collectionImport, completionHandler: nil)
    }
}

/// Weak shim so the WKUserContentController doesn't retain the model.
private final class MessageShim: NSObject, WKScriptMessageHandler {
    private let route: (String, Any) -> Void

    init(router: ScriptMessageRouter) {
        self.route = { [weak router] name, body in router?.route(name: name, body: body) }
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        route(message.name, message.body)
    }
}

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        switch NavigationPolicy.decide(url: url, isMainFrame: isMainFrame) {
        case .allowInWebView:
            decisionHandler(.allow)
        case .openInSafari:
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        case .block:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentURL = webView.url
        detectedCollection = nil
        runCollectionDetect()
    }
}
```

- [ ] **Step 2: Write the SwiftUI wrapper**

`App/WebView/PatreonWebView.swift`:
```swift
import SwiftUI
import WebKit

struct PatreonWebView: UIViewRepresentable {
    let model: WebViewModel

    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
```

- [ ] **Step 3: Write AppEnvironment**

`App/AppEnvironment.swift`:
```swift
import Foundation
import SwiftUI
import WebKit
import ChapterlyCore

@MainActor
@Observable
final class AppEnvironment {
    let store: LibraryStore
    let browse = WebViewModel()
    let reader = WebViewModel()

    var importedCountThisSession = 0

    init() {
        do { store = try LibraryStore.onDisk() }
        catch {
            // Spec §4: corrupted local store → reset. Try in-memory as last resort.
            store = (try? LibraryStore.inMemory()) ?? { fatalError("SwiftData unavailable") }()
        }
        wire(browse)
        wire(reader)
    }

    private var pendingImport: [ImporterChapterPayload] = []
    private var importFlushTask: Task<Void, Never>?

    private func wire(_ model: WebViewModel) {
        model.router.onImporterChapter = { [weak self] payload in
            guard let self else { return }
            pendingImport.append(payload)
            importFlushTask?.cancel()
            importFlushTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let batch = self.pendingImport
                self.pendingImport = []
                try? self.store.applyImport(batch)
                self.importedCountThisSession = batch.count
            }
        }
        model.router.onCollectionLink = { [weak model] payload in
            model?.detectedCollection = payload
        }
        model.router.onProgress = { [weak self] payload in
            self?.store.setProgress(forPageURL: payload.url, progress: payload.scrollProgress)
        }
    }

    /// Spec §3.5 "Logout from Patreon": wipe website data only. Library untouched.
    func logoutFromPatreon() async {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: types)
        await dataStore.removeData(ofTypes: types, for: records)
        browse.load(URL(string: "https://www.patreon.com/login")!)
    }

    /// Spec §3.5 "Clear Library Data": SwiftData only. Session untouched.
    func clearLibraryData() {
        try? store.clearLibrary()
    }
}
```

- [ ] **Step 4: Update AppRootView to hold the environment**

`App/AppRootView.swift` (replace file):
```swift
import SwiftUI

struct AppRootView: View {
    @State private var env = AppEnvironment()

    var body: some View {
        TabView {
            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
            Text("Library")
                .tabItem { Label("Library", systemImage: "books.vertical") }
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(env)
    }
}
```

Add a minimal `App/Features/Browse/BrowseView.swift` placeholder so this compiles (fully built in Task 11):
```swift
import SwiftUI

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        PatreonWebView(model: env.browse)
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                if env.browse.currentURL == nil {
                    env.browse.load(URL(string: "https://www.patreon.com/home")!)
                }
            }
    }
}
```

- [ ] **Step 5: Regenerate project and build**

Run: `xcodegen generate && xcodebuild -project Chapterly.xcodeproj -scheme Chapterly -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Wire WKWebView container, environment, and message routing"
```

---

### Task 11: Browse + Library + TOC screens

Spec §3.5 screens 1–3 and 6. List-first, calm, editorial; no cards-in-cards, no dashboard widgets (spec §5).

**Files:**
- Modify: `App/Features/Browse/BrowseView.swift`
- Create: `App/Features/Library/LibraryView.swift`
- Create: `App/Features/Library/CollectionTOCView.swift`
- Modify: `App/AppRootView.swift`

- [ ] **Step 1: Build BrowseView with import affordances**

Replace `App/Features/Browse/BrowseView.swift`:
```swift
import SwiftUI
import ChapterlyCore

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showImportConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            banner
            PatreonWebView(model: env.browse)
        }
        .onAppear {
            if env.browse.currentURL == nil {
                env.browse.load(URL(string: "https://www.patreon.com/home")!)
            }
        }
        .alert(env.importedCountThisSession == 0 ? "No chapters found" : "Chapters imported",
               isPresented: $showImportConfirmation) {
            Button("OK") {}
        } message: {
            if env.importedCountThisSession == 0 {
                // Spec §4: import finds 0 chapters → hint + manual-add pointer.
                Text("No chapter links were found on this page. Patreon's markup may have changed — you can add chapters manually from the collection's page in Library.")
            } else {
                Text("Imported \(env.importedCountThisSession) visible chapters. Scroll the collection page to load more, then import again — already-imported chapters are merged, not duplicated.")
            }
        }
    }

    @ViewBuilder
    private var banner: some View {
        if env.browse.isOnCollectionPage {
            HStack {
                Label("Collection page", systemImage: "books.vertical")
                    .font(.subheadline)
                Spacer()
                Button("Import visible chapters") {
                    env.browse.runCollectionImport()
                    Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        showImportConfirmation = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        } else if let link = env.browse.detectedCollection {
            HStack {
                Text("Series: \(link.collectionName)")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Button("Open collection") {
                    if let url = URLNormalizer.normalize(link.collectionURL) {
                        env.browse.load(url)
                    }
                }
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}
```

- [ ] **Step 2: Build LibraryView with empty state**

`App/Features/Library/LibraryView.swift`:
```swift
import SwiftUI
import SwiftData
import ChapterlyCore

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \LocalCollectionModel.title) private var collections: [LocalCollectionModel]

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(collections) { collection in
                            NavigationLink(value: collection.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(collection.title).font(.headline)
                                    Text("\(collection.chapters.count) chapters")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { env.store.deleteCollection(collections[i]) }
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: String.self) { id in
                        if let collection = collections.first(where: { $0.id == id }) {
                            CollectionTOCView(collection: collection)
                        }
                    }
                }
            }
            .navigationTitle("Library")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No collections yet", systemImage: "books.vertical")
        } description: {
            Text("Browse to a Patreon post, open its series page, and tap “Import visible chapters”.")
        }
    }
}
```

- [ ] **Step 3: Build CollectionTOCView (edit mode, reverse toggle, manual add)**

`App/Features/Library/CollectionTOCView.swift`:
```swift
import SwiftUI
import ChapterlyCore

struct CollectionTOCView: View {
    @Environment(AppEnvironment.self) private var env
    let collection: LocalCollectionModel
    @State private var readerChapterID: String?
    @State private var showAddSheet = false
    @State private var newTitle = ""
    @State private var newURL = ""
    @State private var renameTarget: LocalChapterModel?
    @State private var renameText = ""

    private var chapters: [LocalChapterModel] { env.store.orderedChapters(of: collection) }

    var body: some View {
        List {
            ForEach(chapters) { chapter in
                Button {
                    readerChapterID = chapter.id
                } label: {
                    chapterRow(chapter)
                }
                .foregroundStyle(.primary)
                .swipeActions {
                    Button("Delete", role: .destructive) { env.store.delete(chapter) }
                    Button("Rename") {
                        renameTarget = chapter
                        renameText = chapter.title
                    }
                }
            }
            .onMove { source, destination in
                env.store.moveChapters(in: collection, from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    collection.sortDirection =
                        collection.sortDirection == .oldestToNewest ? .newestToOldest : .oldestToNewest
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Reverse chapter order")
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add chapter manually")
                EditButton()
            }
        }
        .fullScreenCover(item: $readerChapterID) { id in
            if let chapter = chapters.first(where: { $0.id == id }) {
                ReaderView(chapter: chapter)
            }
        }
        .alert("Rename chapter", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } })) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let t = renameTarget { env.store.rename(t, to: renameText) }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                Form {
                    TextField("Title", text: $newTitle)
                    TextField("Patreon post URL", text: $newURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                .navigationTitle("Add chapter")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            try? env.store.addManualChapter(to: collection, title: newTitle, urlString: newURL)
                            newTitle = ""; newURL = ""; showAddSheet = false
                        }
                        .disabled(newTitle.isEmpty || URLNormalizer.normalize(newURL) == nil)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func chapterRow(_ chapter: LocalChapterModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.title).font(.body)
                if let date = chapter.visibleDateText {
                    Text(date).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let progress = chapter.readingProgress {
                if progress >= 0.97 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Finished")
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(Int(progress * 100)) percent read")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
```

(If the `@retroactive Identifiable` extension on `String` causes grief, replace `readerChapterID: String?` with a small `struct ReaderTarget: Identifiable { let id: String }` — keep the cover API the same.)

- [ ] **Step 4: Wire tabs**

In `App/AppRootView.swift` replace `Text("Library")` with `LibraryView()`.

- [ ] **Step 5: Build**

`ReaderView` doesn't exist yet — add a temporary stub `App/Features/Reader/ReaderView.swift` so this compiles (replaced in Task 12):
```swift
import SwiftUI
import ChapterlyCore

struct ReaderView: View {
    let chapter: LocalChapterModel
    var body: some View { Text(chapter.title) }
}
```

Run: `xcodegen generate && xcodebuild -project Chapterly.xcodeproj -scheme Chapterly -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add Browse import flow, Library, and TOC screens"
```

---

### Task 12: Reader screen

Spec §3.2. Webview + reader CSS + native prev/next bars + font size + progress restore.

**Files:**
- Modify: `App/Features/Reader/ReaderView.swift` (replace stub)
- Create: `App/Features/Reader/ReaderPreferences.swift`

- [ ] **Step 1: Preferences**

`App/Features/Reader/ReaderPreferences.swift`:
```swift
import SwiftUI

@MainActor
@Observable
final class ReaderPreferences {
    var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: "reader.fontSize") }
    }
    var readerModeEnabled: Bool {
        didSet { UserDefaults.standard.set(readerModeEnabled, forKey: "reader.enabled") }
    }

    init() {
        let storedSize = UserDefaults.standard.integer(forKey: "reader.fontSize")
        fontSize = storedSize == 0 ? 19 : storedSize
        readerModeEnabled = UserDefaults.standard.object(forKey: "reader.enabled") as? Bool ?? true
    }
}
```

- [ ] **Step 2: ReaderView (replace stub)**

```swift
import SwiftUI
import ChapterlyCore

struct ReaderView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var current: LocalChapterModel
    @State private var prefs = ReaderPreferences()

    init(chapter: LocalChapterModel) {
        _current = State(initialValue: chapter)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            PatreonWebView(model: env.reader)
            bottomBar
        }
        .onAppear { open(current) }
        .onChange(of: env.reader.currentURL) { _, _ in applyReaderTreatment() }
    }

    private var neighbors: (previous: LocalChapterModel?, next: LocalChapterModel?) {
        env.store.neighbors(of: current)
    }

    private func open(_ chapter: LocalChapterModel) {
        current = chapter
        if let url = URL(string: chapter.urlString) {
            env.reader.load(url)
        }
    }

    private func applyReaderTreatment() {
        guard env.reader.currentURL != nil else { return }
        let webView = env.reader.webView
        if prefs.readerModeEnabled {
            webView.evaluateJavaScript(ReaderStyler.injectionScript(), completionHandler: nil)
            webView.evaluateJavaScript(ReaderStyler.fontSizeScript(points: prefs.fontSize),
                                       completionHandler: nil)
        }
        if let progress = current.readingProgress, progress > 0.02, progress < 0.97 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                webView.evaluateJavaScript(
                    ReaderStyler.restoreScrollScript(progress: progress), completionHandler: nil)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Close reader")
            Spacer()
            Text(current.title).font(.subheadline.weight(.medium)).lineLimit(1)
            Spacer()
            Menu {
                Stepper("Font size: \(prefs.fontSize)",
                        value: $prefs.fontSize, in: 14...32)
                Toggle("Reader mode", isOn: $prefs.readerModeEnabled)
                if let url = URL(string: current.urlString) {
                    Link("Open on Patreon", destination: url)
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel("Reading options")
            .onChange(of: prefs.fontSize) { _, size in
                env.reader.webView.evaluateJavaScript(
                    ReaderStyler.fontSizeScript(points: size), completionHandler: nil)
            }
            .onChange(of: prefs.readerModeEnabled) { _, enabled in
                env.reader.webView.evaluateJavaScript(
                    enabled ? ReaderStyler.injectionScript() : ReaderStyler.removalScript(),
                    completionHandler: nil)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var bottomBar: some View {
        HStack {
            if let previous = neighbors.previous {
                Button { open(previous) } label: {
                    Label(previous.title, systemImage: "chevron.left")
                        .lineLimit(1)
                }
            }
            Spacer()
            if let next = neighbors.next {
                Button { open(next) } label: {
                    HStack {
                        Text(next.title).lineLimit(1)
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
```

Note spec deviation handled: spec puts "Previous Chapter" at top, "Next" at bottom. With a webview body, in-flow buttons aren't possible without injecting DOM (which we won't do into Patreon's page beyond CSS), so both live in slim native bars: previous on the bottom-left, next on the bottom-right, title up top. This preserves the function (one-tap prev/next without leaving the reader) while keeping injection CSS-only. If the user objects during smoke test, move prev into the top bar.

- [ ] **Step 3: Build**

Run: `xcodegen generate && xcodebuild -project Chapterly.xcodeproj -scheme Chapterly -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Add reader screen with CSS cleanup, font size, prev/next, progress restore"
```

---

### Task 13: Settings screen

Spec §3.5: font size, reader toggle, **Clear Library Data** and **Logout from Patreon** as separate confirmed actions, about, license.

**Files:**
- Create: `App/Features/Settings/SettingsView.swift`
- Modify: `App/AppRootView.swift`

- [ ] **Step 1: Build SettingsView**

```swift
import SwiftUI
import ChapterlyCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var prefs = ReaderPreferences()
    @State private var confirmClearLibrary = false
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    Stepper("Font size: \(prefs.fontSize)", value: $prefs.fontSize, in: 14...32)
                    Toggle("Reader mode by default", isOn: $prefs.readerModeEnabled)
                }

                Section {
                    Button("Clear Library Data", role: .destructive) { confirmClearLibrary = true }
                    Button("Logout from Patreon", role: .destructive) { confirmLogout = true }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Clear Library Data deletes collections, chapters, and reading progress stored on this device. Logout from Patreon ends the website session in the built-in browser. The two are independent.")
                }

                Section("About") {
                    LabeledContent("Version", value: ChapterlyCore.version)
                    Text("Chapterly is a local-only reading shell for your own Patreon session. It stores chapter titles, links, and reading progress on this device — never post content. Patreon controls all access to posts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all collections, chapters, and reading progress?",
                                isPresented: $confirmClearLibrary, titleVisibility: .visible) {
                Button("Clear Library Data", role: .destructive) { env.clearLibraryData() }
            }
            .confirmationDialog("End your Patreon session in the built-in browser?",
                                isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Logout from Patreon", role: .destructive) {
                    Task { await env.logoutFromPatreon() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Wire tab**

In `App/AppRootView.swift` replace `Text("Settings")` with `SettingsView()`.

- [ ] **Step 3: Build**

Run: `xcodegen generate && xcodebuild -project Chapterly.xcodeproj -scheme Chapterly -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Add settings with independent clear-library and logout actions"
```

---

### Task 14: Docs + manual smoke test

Spec §8 deliverables: COMPLIANCE.md, README.md, smoke checklist.

**Files:**
- Create: `COMPLIANCE.md`
- Create: `README.md`

- [ ] **Step 1: Write COMPLIANCE.md**

```markdown
# Chapterly Compliance Notes

## What Chapterly is

A local-only iOS reading shell. The user logs into patreon.com inside the app's
WKWebView with their own account. Patreon serves every page and enforces all
access control. Chapterly only restyles what Patreon already shows the user and
remembers chapter links and reading position locally.

## What Chapterly never does

- Never reads, copies, or exports session cookies or website data
  (the `WKWebsiteDataStore` is only ever wiped on logout, never enumerated)
- Never intercepts Patreon network responses
- Never calls Patreon APIs (official or internal)
- Never stores post bodies or page HTML — a strict native-side payload
  validator rejects any script message containing content-like fields
  (`bodyText`, `innerHTML`, `html`, `content`, ...), unknown keys, or
  oversized payloads
- Never provides offline reading, export, or sharing of paid content
- Never aggregates content across users (there is no backend at all)
- Never sends post content to analytics, crash logs, or AI APIs (none are integrated)

## What is stored locally

Chapter titles, Patreon post URLs, visible date strings, manual ordering,
collection names/URLs, reading progress percentages, font preferences.
Nothing else.

## Data deletion

- **Clear Library Data** (Settings) deletes all stored metadata.
- **Logout from Patreon** (Settings) wipes the webview website data store,
  ending the session.

## When access is revoked

Nothing is cached, so a revoked membership simply shows Patreon's own locked
page inside the webview. Chapterly has no content to keep showing.

## Remaining risks

- Client-side restyling of a logged-in page is comparable to Safari Reader
  Mode or a content blocker, but Patreon's Terms of Use do not explicitly
  bless it. Chapterly is distributed as sideloaded, open-source, personal-use
  software partly for this reason.
- Patreon markup changes can break the reader CSS and the collection importer.
  Degradation is graceful (plain Patreon page; manual chapter entry).
```

- [ ] **Step 2: Write README.md**

```markdown
# Chapterly

A calm, local-only reading shell for your own Patreon session. Log into
patreon.com inside the app, import a series' chapter list from its collection
page, and read with clean typography, previous/next chapter navigation, and
locally saved reading progress.

Chapterly is **not** a Patreon client or API consumer. It never bypasses
access control, never stores post content, and has no backend. See
[COMPLIANCE.md](COMPLIANCE.md).

## Requirements

- Xcode 15.4+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An iPhone (sideload) or the iOS simulator

## Build

```bash
git clone <this repo>
cd Chapterly
xcodegen generate
open Chapterly.xcodeproj
```

Select the Chapterly scheme, set your own signing team (Signing & Capabilities),
and run on a device or simulator.

## Tests

```bash
swift test --package-path ChapterlyCore
```

## Sideloading for non-developers

Any of: AltStore / SideStore with the built `.ipa`, or a free Apple developer
certificate in Xcode (7-day resign cycle), or an Apple Developer Program
membership (1-year certificates). Each user signs the app themselves and logs
in with their own Patreon account.

## Using the app

1. **Browse** tab → log into patreon.com (email login; third-party SSO that
   leaves patreon.com opens in Safari by design — prefer email login).
2. Open a post in a series → tap **Open collection** when the series banner
   appears → on the collection page tap **Import visible chapters**.
   Scroll to load more chapters and import again; re-imports merge.
3. **Library** tab → pick the collection → tap a chapter to read.
4. Reader: font size and reader-mode toggle in the top-right menu;
   previous/next chapter in the bottom bar.

## Known limitations

- Patreon markup changes can break reader styling and import — both degrade
  gracefully; chapter lists can always be edited or entered manually.
- Reading progress is approximate (lazy-loaded images shift page height).
- No offline reading, by design.

## What not to implement

Cookie access, network interception, Patreon API calls, content storage or
export, cross-user sharing — see COMPLIANCE.md. Pull requests adding any of
these will be declined.
```

- [ ] **Step 3: Manual smoke checklist (run on simulator or device, real account)**

Verify and note results in the commit message:
1. Login on Browse tab works and survives app relaunch.
2. Open a series post → series banner appears → Open collection → Import → Library shows the collection with correct titles (CJK intact) and order.
3. Scroll collection page, import again → no duplicates, new chapters appended.
4. Reverse-order toggle flips TOC and prev/next direction.
5. Reader: CSS cleanup applies; font stepper works live; prev/next navigate; progress saves and restores on reopen.
6. External link in a post opens Safari, not the webview.
7. Clear Library Data → library empty, still logged in on Browse.
8. Logout from Patreon → logged out, library intact.
9. Open a locked post (creator you don't support) → Patreon's own locked page shows; nothing else.

- [ ] **Step 4: Run full test suite one final time**

Run: `swift test --package-path ChapterlyCore`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add COMPLIANCE.md and README; record smoke test results"
```

---

## Out of scope (do not build)

Bookmarks (v1.1), themes beyond system light/dark, search, filters, locked-chapter UI, chapter-number title parsing, offline reading, export, Patreon OAuth/API, any backend. If a task seems to need one of these, stop and ask.
