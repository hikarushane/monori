import Foundation
import SwiftUI
import WebKit
import ChapterlyCore
import os

private let smokeLog = Logger(subsystem: "dev.chapterly", category: "smoke-diagnostics")

@MainActor
@Observable
final class AppEnvironment {
    let store: LibraryStore
    let browse = WebViewModel()
    let reader = WebViewModel()

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
            model?.detectedCollection = payload
        }
        model.router.onProgress = { [weak self] payload in
            guard let self else { return }
            let matched = self.store.chapter(withPageURL: payload.url) != nil
            self.store.setProgress(forPageURL: payload.url, progress: payload.scrollProgress)
            if Self.isSmokeMode {
                smokeLog.notice("[SMOKE] progress_payload_received matched=\(matched) value=\(payload.scrollProgress)")
            }
        }
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
