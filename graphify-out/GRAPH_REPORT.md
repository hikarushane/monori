# Graph Report - Chapterly  (2026-06-15)

## Corpus Check
- 60 files · ~28,176 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 647 nodes · 887 edges · 42 communities (38 shown, 4 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e320e236`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Navigation Policy Tests|Navigation Policy Tests]]
- [[_COMMUNITY_Project Docs and Agent Rules|Project Docs and Agent Rules]]
- [[_COMMUNITY_LibraryStore and Data Management|LibraryStore and Data Management]]
- [[_COMMUNITY_BackSwipe Policy|BackSwipe Policy]]
- [[_COMMUNITY_App Root and Navigation|App Root and Navigation]]
- [[_COMMUNITY_WebViewModel|WebViewModel]]
- [[_COMMUNITY_AppEnvironment and Auth|AppEnvironment and Auth]]
- [[_COMMUNITY_Smoke AutoPilot|Smoke AutoPilot]]
- [[_COMMUNITY_PatreonWebView|PatreonWebView]]
- [[_COMMUNITY_JS Extraction Tests|JS Extraction Tests]]
- [[_COMMUNITY_ChapterMapMerger|ChapterMapMerger]]
- [[_COMMUNITY_ReaderView|ReaderView]]
- [[_COMMUNITY_Script Message Router|Script Message Router]]
- [[_COMMUNITY_CollectionImport JS|CollectionImport JS]]
- [[_COMMUNITY_PayloadValidator|PayloadValidator]]
- [[_COMMUNITY_PayloadValidator Tests|PayloadValidator Tests]]
- [[_COMMUNITY_Data Models|Data Models]]
- [[_COMMUNITY_ChapterTextFormatter Tests|ChapterTextFormatter Tests]]
- [[_COMMUNITY_ReaderStyler CSS Injection|ReaderStyler CSS Injection]]
- [[_COMMUNITY_NavigationPolicy Core|NavigationPolicy Core]]
- [[_COMMUNITY_URLNormalizer|URLNormalizer]]
- [[_COMMUNITY_BackSwipe Policy Tests|BackSwipe Policy Tests]]
- [[_COMMUNITY_UI Driver Scripts|UI Driver Scripts]]
- [[_COMMUNITY_Smoke Test Support|Smoke Test Support]]
- [[_COMMUNITY_CardTreatment JS|CardTreatment JS]]
- [[_COMMUNITY_ReaderPreferences|ReaderPreferences]]
- [[_COMMUNITY_UI Preflight Scripts|UI Preflight Scripts]]
- [[_COMMUNITY_App Entry Point|App Entry Point]]
- [[_COMMUNITY_JS Assets|JS Assets]]
- [[_COMMUNITY_Smoke Auto Scripts|Smoke Auto Scripts]]
- [[_COMMUNITY_Smoke Diagnostics Scripts|Smoke Diagnostics Scripts]]
- [[_COMMUNITY_ChapterlyCore Package|ChapterlyCore Package]]
- [[_COMMUNITY_Verify Scripts|Verify Scripts]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]

## God Nodes (most connected - your core abstractions)
1. `Debugging and Testing Rules` - 20 edges
2. `Debugging and Testing Rules` - 19 edges
3. `AppEnvironment` - 18 edges
4. `WebViewModel` - 18 edges
5. `LibraryStore` - 18 edges
6. `SmokeAutopilot` - 17 edges
7. `LibraryStoreTests` - 17 edges
8. `ReaderView` - 15 edges
9. `JSExtractionTests` - 15 edges
10. `ReaderStylerTests` - 15 edges

## Surprising Connections (you probably didn't know these)
- `MEMORY` --semantically_similar_to--> `HANDOFF`  [INFERRED] [semantically similar]
  MEMORY.md → HANDOFF.md
- `MEMORY` --references--> `PayloadValidator — Native-Side Script Message Validator`  [EXTRACTED]
  MEMORY.md → COMPLIANCE.md
- `HANDOFF` --references--> `SIMULATOR_PLAYBOOK.md — Agent-Driven Simulator UI Automation`  [EXTRACTED]
  HANDOFF.md → SIMULATOR_PLAYBOOK.md
- `README.md — Chapterly App Overview` --references--> `COMPLIANCE.md — Chapterly Compliance Notes`  [EXTRACTED]
  README.md → COMPLIANCE.md
- `post_page.html — Single Post Page Fixture` --references--> `Patreon Collection Page DOM — post links, lazy load, load-more patterns`  [INFERRED]
  ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/post_page.html → ChapterlyCore/Tests/ChapterlyCoreTests/Fixtures/collection_page.html

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Simulator Automation Pipeline** — concept_ui_driver_sh, concept_computer_use_mcp, concept_reader_dismiss_button, concept_accessibility_identifiers, simulator_playbook_simulator_playbook [INFERRED 0.85]
- **Collection Import Pipeline** — concept_collection_import_js, concept_payload_validator, concept_collection_page_dom, concept_excerpt_from_card, concept_looks_like_body_text [INFERRED 0.85]
- **Smoke Test Script Suite** — concept_verify_sh, concept_smoke_diagnostics_sh, concept_smoke_auto_sh, concept_preflight_diagnostics, concept_build_smoke_artifacts [EXTRACTED 0.95]

## Communities (42 total, 4 thin omitted)

### Community 0 - "Navigation Policy Tests"
Cohesion: 0.40
Nodes (4): adr/（架構決策）, errors/（踩過的坑）, patterns/（可複用模式）, WIKI_SYNC

### Community 1 - "Project Docs and Agent Rules"
Cohesion: 0.18
Nodes (11): Patreon Collection Page DOM — post links, lazy load, load-more patterns, Patreon Post Card DOM — data-tag post-card, teaser text, Show more patterns, collection_page.html — Basic Collection Page Fixture, collection_page_card_excerpt.html — Card with Excerpt Fixture, collection_page_empty_anchor_text.html — Empty Anchor Text Fixture, collection_page_large_card_text.html — Large Card Text Fixture, collection_page_lazy.html — Infinite Scroll Lazy Load Fixture, collection_page_load_more.html — Load More Button Fixture (+3 more)

### Community 2 - "LibraryStore and Data Management"
Cohesion: 0.14
Nodes (8): LibraryStore, ImporterChapterPayload, Int, LocalChapterModel, LocalCollectionModel, String, ModelContainer, ModelContext

### Community 3 - "BackSwipe Policy"
Cohesion: 0.09
Nodes (24): BackSwipeAction, goBack, none, stayAtRoot, BackSwipePolicy, ChapterTextFormatter, ChapterTextPresentation, CollectionLinkPayload (+16 more)

### Community 4 - "App Root and Navigation"
Cohesion: 0.07
Nodes (25): AppRootView, AppTab, browse, library, settings, LocalChapterModel, LocalCollectionModel, String (+17 more)

### Community 5 - "WebViewModel"
Cohesion: 0.06
Nodes (28): Any, Bool, CollectionLinkPayload, Double, Int, String, URL, Void (+20 more)

### Community 6 - "AppEnvironment and Auth"
Cohesion: 0.10
Nodes (18): AppEnvironment, CollectionRefreshOutcome, failed, needsLogin, newChapters, upToDate, Bool, Duration (+10 more)

### Community 7 - "Smoke AutoPilot"
Cohesion: 0.17
Nodes (12): AutopilotReaderTarget, SmokeAutopilot, Bool, Double, Duration, Int, LocalChapterModel, MainActor (+4 more)

### Community 8 - "PatreonWebView"
Cohesion: 0.15
Nodes (13): Bool, Void, WebViewModel, WKWebView, Context, Coordinator, UIGestureRecognizer, UIGestureRecognizerDelegate (+5 more)

### Community 9 - "JS Extraction Tests"
Cohesion: 0.04
Nodes (7): ChapterTextFormatterTests, NavigationPolicyTests, ScriptMessageRouterTests, SmokeSupportTests, SmokeTests, URLNormalizerTests, XCTestCase

### Community 10 - "ChapterMapMerger"
Cohesion: 0.16
Nodes (9): ChapterMapMerger, ChapterRecord, ImporterChapterPayload, Int, String, ImporterChapterPayload, Int, String (+1 more)

### Community 11 - "ReaderView"
Cohesion: 0.15
Nodes (10): Bool, LocalChapterModel, Never, Set, String, Task, URL, Void (+2 more)

### Community 12 - "Script Message Router"
Cohesion: 0.17
Nodes (11): WKScriptMessage, WKUserContentController, ScriptMessageRouter, Any, CollectionLinkPayload, ImporterChapterPayload, PayloadError, Result (+3 more)

### Community 13 - "CollectionImport JS"
Cohesion: 0.26
Nodes (15): collectVisible(), compactText(), creatorNameFromPage(), distinctPostLinkCount(), excerptFromAnchorText(), excerptFromCard(), excerptWithin(), findLoadMoreButton() (+7 more)

### Community 14 - "PayloadValidator"
Cohesion: 0.30
Nodes (9): PayloadValidator, Any, CollectionLinkPayload, ImporterChapterPayload, Int, PayloadError, Result, Set (+1 more)

### Community 15 - "PayloadValidator Tests"
Cohesion: 0.20
Nodes (3): Any, String, PayloadValidatorTests

### Community 16 - "Data Models"
Cohesion: 0.26
Nodes (10): CollectionSortDirection, newestToOldest, oldestToNewest, LocalChapterModel, LocalCollectionModel, Bool, Int, LocalChapterModel (+2 more)

### Community 17 - "ChapterTextFormatter Tests"
Cohesion: 0.06
Nodes (34): COMPLIANCE.md — Chapterly Compliance Notes, computer-use MCP — Desktop Screenshot Simulator Driver (Driver A), PayloadValidator — Native-Side Script Message Validator, ui-driver.sh — idb-based Simulator UI Driver (Driver B), WKWebView + Patreon — Core Reading Shell Architecture, HANDOFF, 🧹 ux-sweep plan 收尾（2026-06-15，使用者要求先做完再還原 hook）, ⚡ 接手要做的事 (+26 more)

### Community 18 - "ReaderStyler CSS Injection"
Cohesion: 0.31
Nodes (4): ReaderStyler, Double, Int, String

### Community 19 - "NavigationPolicy Core"
Cohesion: 0.14
Nodes (13): Artifacts, Driver B setup, Drivers, Failure escalation, Forbidden, Gesture recipes, Human-verification handoff, Install issues — RESOLVED 2026-06-13 (+5 more)

### Community 20 - "URLNormalizer"
Cohesion: 0.36
Nodes (5): Bool, Set, String, URL, URLNormalizer

### Community 21 - "BackSwipe Policy Tests"
Cohesion: 0.31
Nodes (3): String, URL, BackSwipePolicyTests

### Community 22 - "UI Driver Scripts"
Cohesion: 0.39
Nodes (6): fail(), PATH, require_idb(), require_target(), usage(), ui-driver.sh script

### Community 23 - "Smoke Test Support"
Cohesion: 0.29
Nodes (5): SmokeCheck, SmokeReport, Bool, Double, String

### Community 24 - "CardTreatment JS"
Cohesion: 0.57
Nodes (6): collapseShowMore(), compact(), ensureStyle(), isShowMoreLabel(), scan(), treatCard()

### Community 25 - "ReaderPreferences"
Cohesion: 0.40
Nodes (3): Double, Int, ReaderPreferences

### Community 26 - "UI Preflight Scripts"
Cohesion: 0.70
Nodes (4): fail(), log(), PATH, ui-preflight.sh script

### Community 27 - "App Entry Point"
Cohesion: 0.50
Nodes (3): App, ChapterlyApp, Scene

### Community 29 - "Smoke Auto Scripts"
Cohesion: 0.83
Nodes (3): capture_failure_artifacts(), run_phase(), smoke-auto.sh script

### Community 30 - "Smoke Diagnostics Scripts"
Cohesion: 1.00
Nodes (3): fail_report(), log(), smoke-diagnostics.sh script

### Community 35 - "Community 35"
Cohesion: 0.08
Nodes (22): Automated Smoke Loop Command, Bookmark Debugging, Core Rule, Debug Launch Argument, Debugging and Testing Rules, graphify, Import Chapters Debugging, Independent Data Clearing Debugging (+14 more)

### Community 36 - "Community 36"
Cohesion: 0.09
Nodes (21): Core Rule, Debug Launch Argument, Debugging and Testing Rules, graphify, Import Chapters Debugging, Independent Data Clearing Debugging, Patreon Login Rules, Post-footer verification is a manual user step (+13 more)

### Community 37 - "Community 37"
Cohesion: 0.17
Nodes (6): ImporterChapterPayload, Int, LibraryStore, String, URL, LibraryStoreTests

### Community 39 - "Community 39"
Cohesion: 0.25
Nodes (7): NavigationDecision, allowInWebView, block, openInSafari, NavigationPolicy, Bool, URL

### Community 45 - "Community 45"
Cohesion: 0.22
Nodes (8): Build, Chapterly, Known limitations, Requirements, Sideloading for non-developers, Tests, Using the app, What not to implement

### Community 46 - "Community 46"
Cohesion: 0.25
Nodes (7): Chapterly Compliance Notes, Data deletion, Remaining risks, What Chapterly is, What Chapterly never does, What is stored locally, When access is revoked

## Knowledge Gaps
- **206 isolated node(s):** `newChapters`, `upToDate`, `needsLogin`, `failed`, `LibraryStore` (+201 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `JSExtractionTests` connect `WebViewModel` to `JS Extraction Tests`?**
  _High betweenness centrality (0.097) - this node is a cross-community bridge._
- **Why does `ChapterRecord` connect `ChapterMapMerger` to `LibraryStore and Data Management`, `BackSwipe Policy`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Why does `ChapterMapMergerTests` connect `ChapterMapMerger` to `JS Extraction Tests`?**
  _High betweenness centrality (0.090) - this node is a cross-community bridge._
- **What connects `newChapters`, `upToDate`, `needsLogin` to the rest of the system?**
  _209 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `LibraryStore and Data Management` be split into smaller, more focused modules?**
  _Cohesion score 0.14333333333333334 - nodes in this community are weakly interconnected._
- **Should `BackSwipe Policy` be split into smaller, more focused modules?**
  _Cohesion score 0.08907563025210084 - nodes in this community are weakly interconnected._
- **Should `App Root and Navigation` be split into smaller, more focused modules?**
  _Cohesion score 0.0677361853832442 - nodes in this community are weakly interconnected._