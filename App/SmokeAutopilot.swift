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
/// test URL, imports chapters, opens the reader, scrolls, and logs one
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

    // MARK: - Phase 1: auth -> collection -> import -> reader -> css -> progress save

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
        env.browse.runCollectionImport()
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

        // ProgressTracker only saves after a user gesture (touchstart/wheel); fire a
        // synthetic wheel event first so the gate treats this scroll as user-driven.
        env.reader.webView.evaluateJavaScript("""
        window.dispatchEvent(new Event('wheel'));
        \(ReaderStyler.restoreScrollScript(progress: 0.5))
        window.dispatchEvent(new Event('scroll'));
        """, completionHandler: nil)
        let saved = await waitUntil {
            guard let p = chapter.readingProgress else { return false }
            return SmokeCheck.approximatelyEqual(p, 0.5, tolerance: 0.1)
        }
        guard saved else {
            let actual = chapter.readingProgress.map { String(format: "%.2f", $0) } ?? "nil"
            fail("progress_save", "stored_progress=\(actual)")
            return
        }
        pass("progress_save")
    }

    // MARK: - Phase 2: progress restore on relaunch

    private func runPhase2() async {
        guard let chapter = firstChapterWithProgress(),
              let expected = chapter.readingProgress else {
            fail("progress_restore", "no_saved_progress_found")
            return
        }
        guard await openReader(chapter, stepName: "progress_restore") else { return }

        // ReaderView schedules the scroll restore 0.6 s after load; poll until the
        // actual scroll position approaches the stored progress.
        let restored = await waitUntil { [env] in
            guard let actual = await Self.scrollProgress(of: env.reader.webView) else { return false }
            return SmokeCheck.approximatelyEqual(actual, expected, tolerance: 0.1)
        }
        guard restored else {
            let actual = (await Self.scrollProgress(of: env.reader.webView))
                .map { String(format: "%.2f", $0) } ?? "nil"
            let want = String(format: "%.2f", expected)
            fail("progress_restore", "scroll=\(actual)_expected=\(want)")
            return
        }
        pass("progress_restore")
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

    private func firstChapterWithProgress() -> LocalChapterModel? {
        guard let collection = (try? env.store.collections())?.first else { return nil }
        return env.store.orderedChapters(of: collection).first { $0.readingProgress != nil }
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
