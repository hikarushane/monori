#if DEBUG
import Foundation
import WebKit
import ChapterlyCore
import os

struct AutopilotReaderTarget: Identifiable {
    let id: String
    let chapter: LocalChapterModel
}

/// Debug-only smoke autopilot. Activated by the `--smoke-autopilot` /
/// `--smoke-autopilot-phase2` launch arguments (see scripts/smoke-auto.sh).
/// Performs the same actions a user performs manually: loads the user-supplied
/// test URL, imports chapters, opens the reader, toggles a bookmark, and logs one
/// `[SMOKE] step=...` line per step. Never touches cookies, tokens, or page content.
@MainActor
final class SmokeAutopilot {
    private static let log = Logger(subsystem: "dev.chapterly", category: "smoke-diagnostics")

    private unowned let env: AppEnvironment
    private let stepTimeout: Duration = .seconds(30)
    private let pollInterval: Duration = .milliseconds(500)
    private var passCount = 0
    private var failCount = 0

    init(env: AppEnvironment) {
        self.env = env
    }

    func start() {
        Task { @MainActor in
            if AppEnvironment.isAutopilotPhase2 {
                await runPhase2()
            } else {
                await runPhase1()
            }
            Self.log.notice("[SMOKE] autopilot=complete pass=\(self.passCount) fail=\(self.failCount)")
        }
    }

    // MARK: - Phase 1: auth -> collection -> import -> reader -> css -> bookmark save

    private func runPhase1() async {
        guard let testURL = Self.testURL() else {
            fail("auth", "missing_-SmokeTestURL_launch_argument")
            return
        }
        env.browse.load(testURL)

        let loaded = await waitUntil { [env] in
            env.browse.currentURL != nil && !env.browse.webView.isLoading
        }
        let onLogin = env.browse.currentURL?.path.contains("/login") ?? false
        guard loaded, !onLogin else {
            fail("auth", onLogin ? "not_logged_in" : "page_load_timeout")
            return
        }
        pass("auth")

        guard await waitUntil({ [env] in env.browse.isOnCollectionPage }) else {
            fail("collection_detect", "url_path_does_not_contain_/collection/")
            return
        }
        pass("collection_detect")

        let postsLoaded = await waitUntil { [env] in
            let postCount = await Self.jsInt(
                env.browse.webView, "document.querySelectorAll('a[href*=\"/posts/\"]').length")
            return (postCount ?? 0) > 0
        }
        guard postsLoaded else {
            fail("import", "no_post_links_found")
            return
        }
        let handlerReady = await Self.jsBool(
            env.browse.webView,
            "!!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.chapterlyImport)")
        guard handlerReady else {
            fail("import", "import_handler_missing")
            return
        }

        let rejectedBefore = env.browse.router.rejectedCount
        await env.browse.runCollectionImport()
        let imported = await waitUntil { [env] in
            env.importedCountThisSession > 0 && ((try? env.store.collectionCount()) ?? 0) > 0
        }
        guard imported else {
            if env.browse.router.rejectedCount > rejectedBefore {
                let reason = env.browse.router.lastRejectedReason ?? "unknown"
                fail("import", "payload_rejected_\(reason)")
                return
            }
            if env.importedCountThisSession > 0 {
                fail("import", "store_collection_missing")
                return
            }
            fail("import", "no_chapters_imported")
            return
        }
        pass("import")

        guard let chapter = firstChapter() else {
            fail("open_reader", "no_chapter_in_store")
            return
        }
        guard await openReader(chapter, stepName: "open_reader") else { return }
        pass("open_reader")

        let cssProbe = "document.getElementById('\(ReaderStyler.styleElementID)') !== null"
        let cssApplied = await waitUntil { [env] in
            await Self.jsBool(env.reader.webView, cssProbe)
        }
        guard cssApplied else {
            fail("reader_css", "style_element_not_found")
            return
        }
        pass("reader_css")

        // Drive to a known bookmarked state. `toggleBookmark` flips, and the
        // bookmark persists across runs, so a bare toggle is non-deterministic;
        // only toggle when needed. Verify on the just-mutated object — re-fetching
        // by URL here races SwiftData's save and made this step flaky. Persistence
        // across a relaunch is covered separately by phase 2.
        if !chapter.isBookmarked {
            env.store.toggleBookmark(chapter)
        }
        guard chapter.isBookmarked else {
            fail("bookmark_save", "isBookmarked_still_false")
            return
        }
        pass("bookmark_save")
    }

    // MARK: - Phase 2: bookmark persists across relaunch + reader opens at top

    private func runPhase2() async {
        guard let chapter = firstBookmarkedChapter() else {
            fail("bookmark_restore", "no_bookmarked_chapter_found")
            return
        }
        pass("bookmark_restore")

        guard await openReader(chapter, stepName: "reader_top") else { return }
        // ReaderView pins the scroll to the top for a few seconds after load;
        // poll until the page actually sits at (or extremely near) the top.
        let atTop = await waitUntil { [env] in
            guard let p = await Self.scrollProgress(of: env.reader.webView) else { return false }
            return p <= 0.05
        }
        guard atTop else {
            let actual = (await Self.scrollProgress(of: env.reader.webView))
                .map { String(format: "%.2f", $0) } ?? "nil"
            fail("reader_top", "scroll=\(actual)_expected<=0.05")
            return
        }
        pass("reader_top")
    }

    // MARK: - Shared steps

    /// Presents the real ReaderView via AppRootView's smoke-only fullScreenCover
    /// and waits for the chapter page to finish loading.
    private func openReader(_ chapter: LocalChapterModel, stepName: String) async -> Bool {
        env.autopilotReaderTarget = AutopilotReaderTarget(id: chapter.id, chapter: chapter)
        let loaded = await waitUntil { [env] in
            env.reader.currentURL != nil && !env.reader.webView.isLoading
        }
        if !loaded {
            fail(stepName, "reader_load_timeout")
        }
        return loaded
    }

    // MARK: - Helpers

    private func waitUntil(_ condition: @MainActor () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + stepTimeout
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: pollInterval)
        }
        return false
    }

    private func firstChapter() -> LocalChapterModel? {
        guard let collection = (try? env.store.collections())?.first else { return nil }
        return env.store.orderedChapters(of: collection).first
    }

    private func firstBookmarkedChapter() -> LocalChapterModel? {
        guard let collection = (try? env.store.collections())?.first else { return nil }
        return env.store.orderedChapters(of: collection).first { $0.isBookmarked }
    }

    private static func testURL() -> URL? {
        guard let raw = UserDefaults.standard.string(forKey: "SmokeTestURL") else { return nil }
        return URL(string: raw)
    }

    private static func jsBool(_ webView: WKWebView, _ js: String) async -> Bool {
        ((try? await webView.evaluateJavaScript(js)) as? Bool) ?? false
    }

    private static func jsInt(_ webView: WKWebView, _ js: String) async -> Int? {
        let value = try? await webView.evaluateJavaScript(js)
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        return nil
    }

    private static func scrollProgress(of webView: WKWebView) async -> Double? {
        let js = """
        (function () {
          var doc = document.documentElement;
          var max = doc.scrollHeight - window.innerHeight;
          return max > 0 ? window.scrollY / max : 0;
        })()
        """
        return (try? await webView.evaluateJavaScript(js)) as? Double
    }

    private func pass(_ step: String) {
        passCount += 1
        let line = SmokeReport.stepLine(step: step, pass: true, reason: nil)
        Self.log.notice("[SMOKE] \(line, privacy: .public)")
    }

    private func fail(_ step: String, _ reason: String) {
        failCount += 1
        let line = SmokeReport.stepLine(step: step, pass: false, reason: reason)
        Self.log.notice("[SMOKE] \(line, privacy: .public)")
    }
}
#endif
