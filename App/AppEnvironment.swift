import Foundation
import SwiftUI
import WebKit
import MonoriCore
import os

private let smokeLog = Logger(subsystem: "dev.monori", category: "smoke-diagnostics")

enum CollectionRefreshOutcome: Equatable {
    case newChapters(Int)
    case upToDate
    case needsLogin
    case failed
}

@MainActor
@Observable
final class AppEnvironment {
    let store: LibraryStore
    let browse = WebViewModel()
    let reader = WebViewModel()
    // @Observable does not support lazy var — use @ObservationIgnored backing optionals
    // so these two web processes are not spun up until first access.
    @ObservationIgnored private var _googleBrowse: WebViewModel?
    /// Built on first use (Browse → Google Drive) so launch spins up fewer
    /// WKWebViews. Isolated from the Patreon `browse` session.
    var googleBrowse: WebViewModel {
        if _googleBrowse == nil { let m = WebViewModel(); wire(m); _googleBrowse = m }
        return _googleBrowse!
    }
    @ObservationIgnored private var _ao3Browse: WebViewModel?
    var ao3Browse: WebViewModel {
        if _ao3Browse == nil { let m = WebViewModel(); wire(m); _ao3Browse = m }
        return _ao3Browse!
    }
    @ObservationIgnored private var _vocusBrowse: WebViewModel?
    var vocusBrowse: WebViewModel {
        if _vocusBrowse == nil { let m = WebViewModel(); wire(m); _vocusBrowse = m }
        return _vocusBrowse!
    }
    @ObservationIgnored private var _affBrowse: WebViewModel?
    var affBrowse: WebViewModel {
        if _affBrowse == nil { let m = WebViewModel(); wire(m); _affBrowse = m }
        return _affBrowse!
    }
    @ObservationIgnored private var _refresher: WebViewModel?
    /// Offscreen collection re-crawler, built on first refresh.
    var refresher: WebViewModel {
        if _refresher == nil { let m = WebViewModel(); wire(m); _refresher = m }
        return _refresher!
    }
    let prefs = ReaderPreferences()

    var importedCountThisSession = 0
    var ao3ImportCurrent = 0
    var ao3ImportTotal = 0
    private var didStartSmokeTools = false
    private var smokeDiagnosticsTask: Task<Void, Never>?

    static var isSmokeMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-diagnostics")
    }

    static var isAutopilot: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-autopilot") || isAutopilotPhase2
    }

    static var isAutopilotPhase2: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-autopilot-phase2")
    }

    #if DEBUG
    var autopilotReaderTarget: AutopilotReaderTarget?
    private var autopilot: SmokeAutopilot?
    #endif

    init() {
        do { store = try LibraryStore.onDisk() }
        catch {
            store = (try? LibraryStore.inMemory()) ?? { fatalError("SwiftData unavailable") }()
        }
        wire(browse)
        wire(reader)
        // googleBrowse and refresher wire themselves on first access.

        // Pre-warm the default Patreon URL so it's already loading by the time
        // BrowseView appears, reducing perceived cold start latency.
        browse.load(SourceRegistry.patreon.startURL)
    }

    func startSmokeToolsIfNeeded() {
        guard !didStartSmokeTools else { return }
        didStartSmokeTools = true
        if Self.isSmokeMode {
            printSmokeDiagnostics()
            startSmokeDiagnosticsTimer()
        }

        #if DEBUG
        if Self.isAutopilot {
            let autopilot = SmokeAutopilot(env: self)
            self.autopilot = autopilot
            autopilot.start()
        }
        #endif
    }

    private func printSmokeDiagnostics() {
        smokeLog.notice("[SMOKE] === Smoke Diagnostics ===")
        smokeLog.notice("[SMOKE] current_screen=Browse (initial tab)")
        let url = self.browse.currentURL?.absoluteString ?? "<nil>"
        smokeLog.notice("[SMOKE] browse_url=\(url, privacy: .public)")
        let onCollection = self.browse.isOnCollectionPage
        smokeLog.notice("[SMOKE] is_on_collection_page=\(onCollection)")
        let hasDetected = self.browse.detectedCollection != nil
        smokeLog.notice("[SMOKE] detected_collection=\(hasDetected)")
        if let dc = self.browse.detectedCollection {
            smokeLog.notice("[SMOKE] detected_collection_name=\(dc.collectionName, privacy: .public)")
        }
        smokeLog.notice("[SMOKE] import_button_visible=\(onCollection)")
        if !onCollection {
            if self.browse.currentURL == nil {
                smokeLog.notice("[SMOKE] import_hidden_reason=no_url_loaded")
            } else {
                smokeLog.notice("[SMOKE] import_hidden_reason=url_path_does_not_contain_/collection/")
            }
        }
        smokeLog.notice("[SMOKE] imported_count_this_session=\(self.importedCountThisSession)")
        smokeLog.notice("[SMOKE] import_rejected_count=\(self.browse.router.rejectedCount)")
        if let reason = self.browse.router.lastRejectedReason {
            smokeLog.notice("[SMOKE] import_last_rejected_reason=\(reason, privacy: .public)")
        }
        let collectionCount = (try? self.store.collectionCount()) ?? -1
        smokeLog.notice("[SMOKE] library_collection_count=\(collectionCount)")
        smokeLog.notice("[SMOKE] === End Smoke Diagnostics ===")

        if self.browse.isOnCollectionPage {
            self.browse.dumpPageLinks { links in
                smokeLog.notice("[SMOKE] === Page Links Dump ===")
                for line in links.split(separator: "\n").prefix(50) {
                    smokeLog.notice("[SMOKE] link: \(String(line), privacy: .public)")
                }
                smokeLog.notice("[SMOKE] === End Page Links ===")
            }
        }
    }

    private func startSmokeDiagnosticsTimer() {
        guard smokeDiagnosticsTask == nil else { return }
        smokeDiagnosticsTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                printSmokeDiagnostics()
            }
        }
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
                if Self.isSmokeMode {
                    let collectionCount = (try? self.store.collectionCount()) ?? -1
                    smokeLog.notice("[SMOKE] import_payload_batch_count=\(batch.count)")
                    smokeLog.notice("[SMOKE] import_store_collection_count=\(collectionCount)")
                }
            }
        }
        model.router.onCollectionLink = { [weak model] payload in
            // Detect runs against whatever DOM the SPA still shows; by the time the
            // message arrives the user may have left the post (e.g. back to home).
            guard let model, model.isOnPostPage || model.isOnAO3WorkPage || model.isOnVocusRoomPage || model.isOnAFFForewordPage else { return }
            model.detectedCollection = payload
        }
    }

    /// Imports the Google Doc currently shown in `model` into the library.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importGoogleDoc(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              let docID = URLNormalizer.googleDocID(url) else { return 0 }
        guard let html = await model.fetchGoogleDocHTML() else { return 0 }
        let docTitle = model.webView.title ?? "Google Doc"
        let imported = GoogleDocsChapterSplitter.split(html: html, docID: docID, docTitle: docTitle)
        guard !imported.chapters.isEmpty else { return 0 }
        try? store.applyDocImport(imported)
        importedCountThisSession = imported.chapters.count
        return imported.chapters.count
    }

    /// Imports the AO3 work currently shown in `model` into the library.
    /// Multi-chapter works are fetched one by one with a 1 s delay.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importAO3Work(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              let _ = URLNormalizer.ao3WorkID(url) else { return 0 }

        ao3ImportTotal = 0
        ao3ImportCurrent = 0

        let detectedTitle = model.detectedCollection?.collectionName
        let scrapedTitle = try? await model.webView.callAsyncJavaScript(
            "document.querySelector('h2.title.heading')?.textContent?.trim() ?? null",
            contentWorld: .page) as? String
        let workTitle = detectedTitle ?? scrapedTitle ?? "AO3 Work"

        let authorName = try? await model.webView.callAsyncJavaScript(
            "document.querySelector('a[rel=\"author\"]')?.textContent?.trim() ?? null",
            contentWorld: .page) as? String

        guard let navigateHTML = await model.fetchAO3NavigatePage() else { return 0 }
        let entries = AO3ChapterSplitter.parseNavigatePage(html: navigateHTML)

        if entries.isEmpty {
            let contentJS = "document.querySelector('.userstuff')?.innerHTML ?? null"
            guard let content = try? await model.webView.callAsyncJavaScript(
                contentJS, contentWorld: .page) as? String, !content.isEmpty else { return 0 }
            let canonicalURL = URLNormalizer.canonicalAO3WorkURL(url) ?? url
            let imported = ImportedCollection(
                sourceURLString: canonicalURL, title: workTitle, creatorName: authorName,
                sourceKind: .ao3,
                chapters: [ImportedChapter(title: workTitle, urlString: canonicalURL,
                                           orderIndex: 0, contentHTML: content)])
            try? store.applyDocImport(imported)
            importedCountThisSession = 1
            return 1
        }

        ao3ImportTotal = entries.count
        ao3ImportCurrent = 0
        var chapters: [ImportedChapter] = []

        for (index, entry) in entries.enumerated() {
            ao3ImportCurrent = index + 1
            guard let chapterHTML = await model.fetchAO3ChapterPage(path: entry.chapterPath)
            else { continue }
            guard let content = AO3ChapterSplitter.extractChapterContent(html: chapterHTML)
            else { continue }

            let chapterURL = URLNormalizer.canonicalAO3ChapterURL(
                "https://archiveofourown.org\(entry.chapterPath)")
                ?? "https://archiveofourown.org\(entry.chapterPath)"

            chapters.append(ImportedChapter(
                title: entry.title, urlString: chapterURL,
                orderIndex: index, contentHTML: content))

            if index < entries.count - 1 {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        ao3ImportTotal = 0
        ao3ImportCurrent = 0

        guard !chapters.isEmpty else { return 0 }

        let canonicalURL = URLNormalizer.canonicalAO3WorkURL(url) ?? url
        let imported = ImportedCollection(
            sourceURLString: canonicalURL, title: workTitle, creatorName: authorName,
            sourceKind: .ao3, chapters: chapters)
        try? store.applyDocImport(imported)
        importedCountThisSession = chapters.count
        return chapters.count
    }

    /// Imports the Vocus room currently shown in `model` into the library.
    /// Calls VocusRoomImport.js via callAsyncJavaScript and persists results
    /// through applyDocImport with sourceKind .vocus and nil contentHTML.
    /// Returns the number of articles imported (0 on failure / empty).
    @discardableResult
    func importVocusRoom(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              URLNormalizer.isVocusRoomURL(url) else { return 0 }

        let roomTitle = model.detectedCollection?.collectionName ?? "Vocus Room"
        let creatorName = model.detectedCollection?.creatorName

        let result = try? await model.webView.callAsyncJavaScript(
            JSAssets.vocusRoomImport, contentWorld: .page)
        guard let articles = result as? [[String: Any]], !articles.isEmpty else { return 0 }

        let canonicalURL = URLNormalizer.canonicalVocusRoomURL(url) ?? url
        let chapters = articles.enumerated().map { index, dict -> ImportedChapter in
            ImportedChapter(
                title: (dict["title"] as? String) ?? "Article",
                urlString: (dict["url"] as? String) ?? "",
                orderIndex: (dict["domOrder"] as? Int) ?? index)
        }

        let imported = ImportedCollection(
            sourceURLString: canonicalURL,
            title: roomTitle,
            creatorName: creatorName,
            sourceKind: .vocus,
            chapters: chapters)
        try? store.applyDocImport(imported)
        importedCountThisSession = chapters.count
        return chapters.count
    }

    /// Imports the AsianFanfics story currently shown in `model` into the library.
    /// Calls AFFStoryImport.js via callAsyncJavaScript and persists results
    /// through applyDocImport with sourceKind .asianFanfics.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importAFFStory(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              URLNormalizer.isAFFForewordURL(url) else { return 0 }

        let storyTitle = model.detectedCollection?.collectionName ?? "AFF Story"
        let creatorName = model.detectedCollection?.creatorName

        let result = try? await model.webView.callAsyncJavaScript(
            JSAssets.affStoryImport, contentWorld: .page)
        guard let chapters = result as? [[String: Any]], !chapters.isEmpty else { return 0 }

        let canonicalURL = URLNormalizer.canonicalAFFStoryURL(url) ?? url
        let imported = ImportedCollection(
            sourceURLString: canonicalURL,
            title: storyTitle,
            creatorName: creatorName,
            sourceKind: .asianFanfics,
            chapters: chapters.enumerated().map { index, dict -> ImportedChapter in
                ImportedChapter(
                    title: (dict["title"] as? String) ?? "Chapter",
                    urlString: (dict["url"] as? String) ?? "",
                    orderIndex: (dict["domOrder"] as? Int) ?? index)
            })
        try? store.applyDocImport(imported)
        importedCountThisSession = imported.chapters.count
        return imported.chapters.count
    }

    /// Loads the collection's source page in the offscreen refresher web view and
    /// re-runs the chapter import. `applyImport` merges by normalized URL, so
    /// already-imported chapters are untouched and only genuinely new posts land.
    func refreshCollection(_ collection: LocalCollectionModel) async -> CollectionRefreshOutcome {
        guard collection.sourceKind == .patreon else { return .upToDate }
        guard let url = URL(string: collection.sourceURLString) else { return .failed }
        // An offscreen WKWebView needs a real frame for layout-driven lazy lists.
        if refresher.webView.frame.isEmpty {
            refresher.webView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        }
        let countBefore = collection.chapters.count
        let baseline = refresher.finishedNavigationCount
        refresher.load(url)
        let loaded = await waitUntil(timeout: .seconds(30)) { [refresher] in
            refresher.finishedNavigationCount > baseline && !refresher.webView.isLoading
        }
        guard loaded else { return .failed }
        if refresher.currentURL?.path.contains("/login") == true { return .needsLogin }
        await refresher.runCollectionImport()
        // applyImport flushes 300 ms after the last chapter message lands;
        // wait it out before counting.
        try? await Task.sleep(for: .milliseconds(600))
        let delta = collection.chapters.count - countBefore
        // Free the (~200 MB measured) collection DOM the offscreen refresher
        // rendered while crawling the whole collection. Leaving it resident keeps
        // the app near the jetsam threshold, so when the TOC redraws after the
        // refresh the OS can kill + relaunch the app — the "bounce to Library
        // root, then auto re-enter the collection ~5 s later" the user reported.
        // Runs only after the import flush has landed, so it can't drop chapters.
        refresher.webView.loadHTMLString("", baseURL: nil)
        return delta > 0 ? .newChapters(delta) : .upToDate
    }

    private func waitUntil(timeout: Duration,
                           _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

    func logoutFromPatreon() async {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: types)
        await dataStore.removeData(ofTypes: types, for: records)
        browse.load(URL(string: "https://www.patreon.com/login")!)
    }

    func clearLibraryData() {
        try? store.clearLibrary()
    }
}
