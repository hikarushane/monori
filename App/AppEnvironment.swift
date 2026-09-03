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
    /// CAPTCHA / Cloudflare interstitial — needs the user, stop this source for the round.
    case blocked
    /// Source has no offscreen refresh path (Google Docs).
    case unsupported
    case failed
}

@MainActor
@Observable
final class AppEnvironment {
    let store: LibraryStore
    let browse = WebViewModel()
    // @Observable does not support lazy var — use @ObservationIgnored backing optionals
    // so these web processes are not spun up until first access.
    @ObservationIgnored private var _reader: WebViewModel?
    var reader: WebViewModel {
        if _reader == nil { let m = WebViewModel(); wire(m); _reader = m }
        return _reader!
    }
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
    @ObservationIgnored private var _cxcBrowse: WebViewModel?
    var cxcBrowse: WebViewModel {
        if _cxcBrowse == nil { let m = WebViewModel(); wire(m); _cxcBrowse = m }
        return _cxcBrowse!
    }
    @ObservationIgnored private var _slashtwBrowse: WebViewModel?
    var slashtwBrowse: WebViewModel {
        if _slashtwBrowse == nil { let m = WebViewModel(); wire(m); _slashtwBrowse = m }
        return _slashtwBrowse!
    }
    @ObservationIgnored private var _refresher: WebViewModel?
    /// Offscreen collection re-crawler, built on first refresh.
    var refresher: WebViewModel {
        if _refresher == nil { let m = WebViewModel(); wire(m); _refresher = m }
        return _refresher!
    }
    @ObservationIgnored private var _autoCheck: AutoCheckCoordinator?
    /// Foreground new-chapter checker, built on first Library visit.
    var autoCheck: AutoCheckCoordinator {
        if _autoCheck == nil { _autoCheck = AutoCheckCoordinator(env: self) }
        return _autoCheck!
    }
    let readerFontStore = ReaderFontStore()
    let prefs = ReaderPreferences()
    let appPrefs = AppPreferences()
    @ObservationIgnored private var _backupService: ICloudBackupService?
    var backupService: ICloudBackupService {
        if _backupService == nil {
            let transport = CloudKitBackupTransport(containerID: "iCloud.dev.monori")
            _backupService = ICloudBackupService(transport: transport, store: store)
        }
        return _backupService!
    }

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
        // reader, googleBrowse, and others wire themselves on first access.

        // Pre-warm the default Patreon URL so it's already loading by the time
        // BrowseView appears, reducing perceived cold start latency.
        browse.load(SourceRegistry.patreon.startURL)

        validateFontSelection()
    }

    init(store: LibraryStore) {
        self.store = store
        wire(browse)
    }

    func validateFontSelection() {
        let id = prefs.selectedFontID
        guard id != ReaderPreferences.defaultFontID else { return }
        if readerFontStore.descriptor(for: id) == nil {
            prefs.resetFontToDefault()
            DiagnosticLog.shared.log(category: "font",
                "selected font \(id) missing, reset to default")
        }
    }

    func resolvedFontCSS() -> ReaderFontCSS {
        readerFontStore.resolveCSS(for: prefs.selectedFontID)
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
                DiagnosticLog.shared.log(category: "import",
                    "web import batch applied: \(batch.count) chapters")
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
            guard let model, model.isOnPostPage || model.isOnAO3WorkPage || model.isOnVocusRoomPage || model.isOnAFFForewordPage || model.isOnCXCWorkPage || model.isOnSlashTWThreadPage else { return }
            model.detectedCollection = payload
            DiagnosticLog.shared.log(category: "import",
                "collection detected: \(payload.collectionName)")
        }
    }

    /// Imports the Google Doc currently shown in `model` into the library.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importGoogleDoc(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              let docID = URLNormalizer.googleDocID(url) else {
            DiagnosticLog.shared.error(category: "import",
                "google-docs: current URL is not a doc")
            return 0
        }
        guard let html = await model.fetchGoogleDocHTML() else {
            DiagnosticLog.shared.error(category: "import",
                "google-docs: HTML fetch failed")
            return 0
        }
        let docTitle = model.webView.title ?? "Google Doc"
        let imported = GoogleDocsChapterSplitter.split(html: html, docID: docID, docTitle: docTitle)
        guard !imported.chapters.isEmpty else {
            DiagnosticLog.shared.error(category: "import",
                "google-docs: split produced 0 chapters")
            return 0
        }
        try? store.applyDocImport(imported)
        importedCountThisSession = imported.chapters.count
        DiagnosticLog.shared.log(category: "import",
            "google-docs: imported \(imported.chapters.count) chapters")
        return imported.chapters.count
    }

    /// Imports the AO3 work currently shown in `model` into the library.
    /// Multi-chapter works are fetched one by one with a 1 s delay.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importAO3Work(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              let _ = URLNormalizer.ao3WorkID(url) else {
            DiagnosticLog.shared.error(category: "import",
                "ao3: current URL is not a work")
            return 0
        }

        ao3ImportTotal = 0
        ao3ImportCurrent = 0

        // Detection is the primary source; the page scrape covers the case where
        // the banner payload never arrived (e.g. detect ran before the preface
        // rendered). Both must survive — see AO3WorkMeta.js on why it `return`s.
        let metaResult = try? await model.webView.callAsyncJavaScript(
            JSAssets.ao3WorkMeta, contentWorld: .page)
        let meta = metaResult as? [String: Any]

        let workTitle = model.detectedCollection?.collectionName
            ?? (meta?["title"] as? String)
            ?? "AO3 Work"
        let authorName = model.detectedCollection?.creatorName
            ?? (meta?["author"] as? String)

        guard let navigateHTML = await model.fetchAO3NavigatePage() else {
            DiagnosticLog.shared.error(category: "import",
                "ao3: navigate page fetch failed")
            return 0
        }
        let entries = AO3ChapterSplitter.parseNavigatePage(html: navigateHTML)

        if entries.isEmpty {
            let contentResult = try? await model.webView.callAsyncJavaScript(
                JSAssets.ao3WorkContent, contentWorld: .page)
            guard let content = contentResult as? String, !content.isEmpty else {
                DiagnosticLog.shared.error(category: "import",
                    "ao3: single-chapter content extraction failed")
                return 0
            }
            let canonicalURL = URLNormalizer.canonicalAO3WorkURL(url) ?? url
            let imported = ImportedCollection(
                sourceURLString: canonicalURL, title: workTitle, creatorName: authorName,
                sourceKind: .ao3,
                chapters: [ImportedChapter(title: workTitle, urlString: canonicalURL,
                                           orderIndex: 0, contentHTML: content)])
            try? store.applyDocImport(imported)
            importedCountThisSession = 1
            DiagnosticLog.shared.log(category: "import",
                "ao3: imported 1 chapter (single)")
            return 1
        }

        ao3ImportTotal = entries.count
        ao3ImportCurrent = 0
        let fetched = await AO3ChapterSplitter.fetchChapterContents(
            entries: entries,
            waitBetweenRequests: { try? await Task.sleep(for: .seconds(1)) },
            fetchPage: { entryPath in
                await model.fetchAO3ChapterPage(path: entryPath)
            },
            didStartRequest: { requestNumber in
                ao3ImportCurrent = requestNumber
            })
        let chapters = fetched.map { chapter in
            let chapterURL = URLNormalizer.canonicalAO3ChapterURL(
                "https://archiveofourown.org\(chapter.entry.chapterPath)")
                ?? "https://archiveofourown.org\(chapter.entry.chapterPath)"
            return ImportedChapter(
                title: chapter.entry.title, urlString: chapterURL,
                orderIndex: chapter.orderIndex, contentHTML: chapter.contentHTML)
        }

        ao3ImportTotal = 0
        ao3ImportCurrent = 0

        guard !chapters.isEmpty else {
            DiagnosticLog.shared.error(category: "import",
                "ao3: 0 of \(entries.count) chapters extracted")
            return 0
        }

        let canonicalURL = URLNormalizer.canonicalAO3WorkURL(url) ?? url
        let imported = ImportedCollection(
            sourceURLString: canonicalURL, title: workTitle, creatorName: authorName,
            sourceKind: .ao3, chapters: chapters)
        try? store.applyDocImport(imported)
        importedCountThisSession = chapters.count
        DiagnosticLog.shared.log(category: "import",
            "ao3: imported \(chapters.count)/\(entries.count) chapters")
        return chapters.count
    }

    /// Imports the Vocus room currently shown in `model` into the library.
    /// Calls VocusRoomImport.js via callAsyncJavaScript and persists results
    /// through applyDocImport with sourceKind .vocus and nil contentHTML.
    /// Returns the number of articles imported (0 on failure / empty).
    @discardableResult
    func importVocusRoom(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              URLNormalizer.isVocusRoomURL(url) else {
            DiagnosticLog.shared.error(category: "import",
                "vocus: current URL is not a room")
            return 0
        }

        let roomTitle = model.detectedCollection?.collectionName ?? "Vocus Room"
        let creatorName = model.detectedCollection?.creatorName

        let result = try? await model.webView.callAsyncJavaScript(
            JSAssets.vocusRoomImport, contentWorld: .page)
        guard let articles = result as? [[String: Any]], !articles.isEmpty else {
            DiagnosticLog.shared.error(category: "import",
                "vocus: import script returned no articles")
            return 0
        }

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
        DiagnosticLog.shared.log(category: "import",
            "vocus: imported \(chapters.count) articles")
        return chapters.count
    }

    /// Imports the AsianFanfics story currently shown in `model` into the library.
    /// Calls AFFStoryImport.js via callAsyncJavaScript and persists results
    /// through applyDocImport with sourceKind .asianFanfics.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importAFFStory(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL?.absoluteString,
              URLNormalizer.isAFFForewordURL(url) else {
            DiagnosticLog.shared.error(category: "import",
                "aff: current URL is not a foreword")
            return 0
        }

        let storyTitle = model.detectedCollection?.collectionName ?? "AFF Story"
        let creatorName = model.detectedCollection?.creatorName

        let result = try? await model.webView.callAsyncJavaScript(
            JSAssets.affStoryImport, contentWorld: .page)
        guard let chapters = result as? [[String: Any]], !chapters.isEmpty else {
            DiagnosticLog.shared.error(category: "import",
                "aff: import script returned no chapters")
            return 0
        }

        let canonicalURL = URLNormalizer.canonicalAFFStoryURL(url) ?? url
        let imported = ImportedCollection(
            sourceURLString: canonicalURL,
            title: storyTitle,
            creatorName: creatorName,
            sourceKind: .asianFanfics,
            chapters: chapters.enumerated().map { index, dict -> ImportedChapter in
                ImportedChapter(
                    title: (dict["title"] as? String) ?? "Chapter",
                    urlString: URLNormalizer.canonicalAFFChapterURL((dict["url"] as? String) ?? "") ?? (dict["url"] as? String) ?? "",
                    orderIndex: (dict["domOrder"] as? Int) ?? index)
            })
        try? store.applyDocImport(imported)
        importedCountThisSession = imported.chapters.count
        DiagnosticLog.shared.log(category: "import",
            "aff: imported \(imported.chapters.count) chapters")
        return imported.chapters.count
    }

    /// Imports the CXC work currently shown in `model` into the library.
    /// Calls CXCWorkImport.js via callAsyncJavaScript and persists results
    /// through applyDocImport with sourceKind .cxc.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importCXCWork(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL,
              URLNormalizer.isCXCWorkURL(url) else {
            DiagnosticLog.shared.error(category: "import",
                "cxc: current URL is not a work")
            return 0
        }

        let result = try? await model.webView.callAsyncJavaScript(
            JSAssets.cxcWorkImport, contentWorld: .page)
        guard let chapters = result as? [[String: Any]], !chapters.isEmpty else {
            DiagnosticLog.shared.error(category: "import",
                "cxc: import script returned no chapters")
            return 0
        }

        // Prefer import-time title (SPA title may not have been set when detect ran)
        let importTitle = (chapters.first?["collectionName"] as? String)?
            .trimmingCharacters(in: .whitespaces)
        let workTitle: String
        if let t = importTitle, !t.isEmpty {
            workTitle = t
        } else {
            workTitle = model.detectedCollection?.collectionName ?? "CXC 作品"
        }
        let creatorName = (chapters.first?["creatorName"] as? String)
            ?? model.detectedCollection?.creatorName

        let canonicalURL = URLNormalizer.canonicalCXCWorkURL(url)?.absoluteString ?? url.absoluteString
        let imported = ImportedCollection(
            sourceURLString: canonicalURL,
            title: workTitle,
            creatorName: creatorName,
            sourceKind: .cxc,
            chapters: chapters.enumerated().map { index, dict -> ImportedChapter in
                ImportedChapter(
                    title: (dict["title"] as? String) ?? "Chapter",
                    urlString: (dict["url"] as? String) ?? "",
                    orderIndex: (dict["domOrder"] as? Int) ?? index)
            })
        try? store.applyDocImport(imported)
        importedCountThisSession = imported.chapters.count
        DiagnosticLog.shared.log(category: "import",
            "cxc: imported \(imported.chapters.count) chapters")
        return imported.chapters.count
    }

    /// Imports the slashtw thread currently shown in `model` into the library.
    /// Calls SlashTWThreadImport.js via callAsyncJavaScript and persists results
    /// through applyDocImport with sourceKind .slashtw.
    /// Returns the number of chapters imported (0 on failure / empty).
    @discardableResult
    func importSlashTWThread(from model: WebViewModel) async -> Int {
        guard let url = model.currentURL,
              URLNormalizer.isSlashTWThreadURL(url) else {
            DiagnosticLog.shared.error(category: "import",
                "slashtw: current URL is not a thread")
            return 0
        }

        let threadTitle = model.detectedCollection?.collectionName ?? "在水裡寫字討論串"
        let creatorName = model.detectedCollection?.creatorName

        let result = try? await model.webView.callAsyncJavaScript(
            JSAssets.slashtwThreadImport, contentWorld: .page)
        guard let chapters = result as? [[String: Any]], !chapters.isEmpty else {
            DiagnosticLog.shared.error(category: "import",
                "slashtw: import script returned no chapters")
            return 0
        }

        let canonicalURL = URLNormalizer.canonicalSlashTWThreadURL(url)?.absoluteString ?? url.absoluteString
        let imported = ImportedCollection(
            sourceURLString: canonicalURL,
            title: threadTitle,
            creatorName: creatorName,
            sourceKind: .slashtw,
            chapters: chapters.enumerated().map { index, dict -> ImportedChapter in
                ImportedChapter(
                    title: (dict["title"] as? String) ?? "Chapter",
                    urlString: (dict["url"] as? String) ?? "",
                    orderIndex: (dict["domOrder"] as? Int) ?? index)
            })
        try? store.applyDocImport(imported)
        importedCountThisSession = imported.chapters.count
        DiagnosticLog.shared.log(category: "import",
            "slashtw: imported \(imported.chapters.count) chapters")
        return imported.chapters.count
    }

    /// Loads the collection's source page in the offscreen refresher web view and
    /// re-runs the chapter import. `applyImport` merges by normalized URL, so
    /// already-imported chapters are untouched and only genuinely new posts land.
    func refreshCollection(_ collection: LocalCollectionModel) async -> CollectionRefreshOutcome {
        guard collection.sourceKind.supportsAutoCheck else { return .unsupported }
        guard let url = URL(string: collection.sourceURLString) else {
            DiagnosticLog.shared.error(category: "refresh", "invalid source URL")
            return .failed
        }
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
        guard loaded else {
            DiagnosticLog.shared.error(category: "refresh", "page load timed out")
            return .failed
        }
        if refresher.currentURL?.path.contains("/login") == true {
            DiagnosticLog.shared.log(category: "refresh", "needs login")
            return .needsLogin
        }
        if await refresherShowsHumanChallenge() {
            DiagnosticLog.shared.log(category: "refresh", "human verification page, stopping")
            return .blocked
        }
        switch collection.sourceKind {
        case .patreon:
            await refresher.runCollectionImport()
            // applyImport flushes 300 ms after the last chapter message lands;
            // wait it out before counting.
            try? await Task.sleep(for: .milliseconds(600))
        case .vocus:
            let ok = await runVocusRefresherImport(for: collection)
            guard ok else {
                refresher.webView.loadHTMLString("", baseURL: nil)
                return .failed
            }
        case .asianFanfics:
            let ok = await runAFFRefresherImport(for: collection)
            guard ok else {
                refresher.webView.loadHTMLString("", baseURL: nil)
                return .failed
            }
        case .ao3:
            let ok = await runAO3RefresherImport(for: collection)
            guard ok else {
                refresher.webView.loadHTMLString("", baseURL: nil)
                return .failed
            }
        case .googleDocs, .cxc, .slashtw:
            return .unsupported
        }
        let delta = collection.chapters.count - countBefore
        // Free the (~200 MB measured) collection DOM the offscreen refresher
        // rendered while crawling the whole collection. Leaving it resident keeps
        // the app near the jetsam threshold, so when the TOC redraws after the
        // refresh the OS can kill + relaunch the app — the "bounce to Library
        // root, then auto re-enter the collection ~5 s later" the user reported.
        // Runs only after the import flush has landed, so it can't drop chapters.
        refresher.webView.loadHTMLString("", baseURL: nil)
        DiagnosticLog.shared.log(category: "refresh",
            delta > 0 ? "found \(delta) new chapters" : "up to date")
        return delta > 0 ? .newChapters(delta) : .upToDate
    }

    /// Re-runs the Vocus room import against the offscreen refresher.
    /// Titles/creator come from the stored collection (the offscreen refresher
    /// has no `detectedCollection`). Returns false when the script yields no
    /// articles (layout change, error page).
    private func runVocusRefresherImport(for collection: LocalCollectionModel) async -> Bool {
        let result = try? await refresher.webView.callAsyncJavaScript(
            JSAssets.vocusRoomImport, contentWorld: .page)
        guard let articles = result as? [[String: Any]], !articles.isEmpty else {
            DiagnosticLog.shared.error(category: "refresh", "vocus: import script returned no articles")
            return false
        }
        let chapters = articles.enumerated().map { index, dict -> ImportedChapter in
            ImportedChapter(
                title: (dict["title"] as? String) ?? "Article",
                urlString: (dict["url"] as? String) ?? "",
                orderIndex: (dict["domOrder"] as? Int) ?? index)
        }
        let imported = ImportedCollection(
            sourceURLString: collection.sourceURLString,
            title: collection.title,
            creatorName: collection.creatorName,
            sourceKind: .vocus,
            chapters: chapters)
        try? store.applyDocImport(imported)
        return true
    }

    /// Re-runs the AsianFanfics story import against the offscreen refresher.
    /// Titles/creator come from the stored collection. Returns false when the
    /// script yields no chapters.
    private func runAFFRefresherImport(for collection: LocalCollectionModel) async -> Bool {
        let result = try? await refresher.webView.callAsyncJavaScript(
            JSAssets.affStoryImport, contentWorld: .page)
        guard let items = result as? [[String: Any]], !items.isEmpty else {
            DiagnosticLog.shared.error(category: "refresh", "aff: import script returned no chapters")
            return false
        }
        let imported = ImportedCollection(
            sourceURLString: collection.sourceURLString,
            title: collection.title,
            creatorName: collection.creatorName,
            sourceKind: .asianFanfics,
            chapters: items.enumerated().map { index, dict -> ImportedChapter in
                ImportedChapter(
                    title: (dict["title"] as? String) ?? "Chapter",
                    urlString: URLNormalizer.canonicalAFFChapterURL((dict["url"] as? String) ?? "")
                        ?? (dict["url"] as? String) ?? "",
                    orderIndex: (dict["domOrder"] as? Int) ?? index)
            })
        try? store.applyDocImport(imported)
        return true
    }

    /// Re-checks the AO3 work's navigate page for new chapters.
    /// Fetches content HTML only for chapters not already in the collection,
    /// preserving stored offline content for existing chapters.
    private func runAO3RefresherImport(for collection: LocalCollectionModel) async -> Bool {
        guard let navigateHTML = await refresher.fetchAO3NavigatePage() else {
            DiagnosticLog.shared.error(category: "refresh",
                "ao3: navigate page fetch failed")
            return false
        }
        let entries = AO3ChapterSplitter.parseNavigatePage(html: navigateHTML)
        guard !entries.isEmpty else {
            DiagnosticLog.shared.error(category: "refresh",
                "ao3: navigate page returned no chapters")
            return false
        }

        let existingURLs = Set(collection.chapters.map(\.urlString))
        let canonicalURL = URLNormalizer.canonicalAO3WorkURL(
            collection.sourceURLString) ?? collection.sourceURLString

        var chapters: [ImportedChapter] = []
        for (index, entry) in entries.enumerated() {
            let chapterURL = URLNormalizer.canonicalAO3ChapterURL(
                "https://archiveofourown.org\(entry.chapterPath)")
                ?? "https://archiveofourown.org\(entry.chapterPath)"

            if existingURLs.contains(chapterURL) {
                // Existing chapter — pass nil contentHTML; Task 1 fix preserves stored content
                chapters.append(ImportedChapter(
                    title: entry.title, urlString: chapterURL,
                    orderIndex: index))
            } else {
                // New chapter — fetch content
                if !chapters.isEmpty || index > 0 {
                    try? await Task.sleep(for: .seconds(1))
                }
                var contentHTML: String?
                if let chapterPage = await refresher.fetchAO3ChapterPage(path: entry.chapterPath) {
                    contentHTML = AO3ChapterSplitter.extractChapterContent(html: chapterPage)
                }
                chapters.append(ImportedChapter(
                    title: entry.title, urlString: chapterURL,
                    orderIndex: index, contentHTML: contentHTML))
            }
        }

        let imported = ImportedCollection(
            sourceURLString: canonicalURL,
            title: collection.title,
            creatorName: collection.creatorName,
            sourceKind: .ao3,
            chapters: chapters)
        try? store.applyDocImport(imported)
        return true
    }

    /// Detects a Cloudflare / CAPTCHA interstitial in the offscreen refresher.
    /// Detection only — human verification is always a manual user step.
    private func refresherShowsHumanChallenge() async -> Bool {
        if refresher.currentURL?.host?.contains("challenges.cloudflare.com") == true {
            return true
        }
        let title = (try? await refresher.webView.callAsyncJavaScript(
            "return document.title;", contentWorld: .page)) as? String ?? ""
        return title.localizedCaseInsensitiveContains("just a moment")
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

    func clearBrowserData() async {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: types)
        await dataStore.removeData(ofTypes: types, for: records)
        browse.load(URL(string: "about:blank")!)
        DiagnosticLog.shared.log(category: "data", "browser data cleared (logged out)")
    }

    func clearLibraryData() {
        try? store.clearLibrary()
        DiagnosticLog.shared.log(category: "data", "library data cleared")
    }
}
