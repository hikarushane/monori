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
    @ObservationIgnored private var _refresher: WebViewModel?
    /// Offscreen collection re-crawler, built on first refresh.
    var refresher: WebViewModel {
        if _refresher == nil { let m = WebViewModel(); wire(m); _refresher = m }
        return _refresher!
    }
    let prefs = ReaderPreferences()

    var importedCountThisSession = 0
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
            guard let model, model.isOnPostPage else { return }
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

    /// Loads the collection's source page in the offscreen refresher web view and
    /// re-runs the chapter import. `applyImport` merges by normalized URL, so
    /// already-imported chapters are untouched and only genuinely new posts land.
    func refreshCollection(_ collection: LocalCollectionModel) async -> CollectionRefreshOutcome {
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
