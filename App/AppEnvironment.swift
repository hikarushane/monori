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
