import SwiftUI
import ChapterlyCore
import os

private let bannerLog = Logger(subsystem: "dev.chapterly", category: "smoke-diagnostics")

/// Banner shown above a Patreon web view. On a collection page it offers
/// chapter import; on a post that links to a collection it shows the series
/// name with a shortcut to open that collection. Used by both the Browse tab
/// and the reader.
struct WebCollectionBanner: View {
    @Environment(AppEnvironment.self) private var env
    let model: WebViewModel
    @State private var showImportConfirmation = false

    var body: some View {
        banner
            .alert(env.importedCountThisSession == 0 ? "No chapters found" : "Chapters imported",
                   isPresented: $showImportConfirmation) {
                Button("OK") {}
            } message: {
                if env.importedCountThisSession == 0 {
                    Text("No chapter links were found on this page. Patreon's markup may have changed — you can add chapters manually from the collection's page in Library.")
                } else {
                    Text("Imported \(env.importedCountThisSession) visible chapters. Scroll the collection page to load more, then import again — already-imported chapters are merged, not duplicated.")
                }
            }
    }

    @ViewBuilder
    private var banner: some View {
        if model.isOnCollectionPage {
            HStack {
                Label("Collection page", systemImage: "books.vertical")
                    .font(.subheadline)
                Spacer()
                Button("Import visible chapters") {
                    model.runCollectionImport()
                    Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        if AppEnvironment.isSmokeMode && env.importedCountThisSession == 0 {
                            bannerLog.notice("[SMOKE] Import found 0 chapters — dumping page structure")
                            model.dumpPageLinks { dump in
                                for line in dump.split(separator: "\n") {
                                    bannerLog.notice("[SMOKE] \(String(line), privacy: .public)")
                                }
                            }
                        }
                        showImportConfirmation = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("smoke.importChaptersButton")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityIdentifier("smoke.collectionBanner")
        } else if let link = model.detectedCollection {
            HStack {
                Text("Series: \(link.collectionName)")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Button("Open collection") {
                    if let url = URLNormalizer.normalize(link.collectionURL) {
                        model.load(url)
                    }
                }
                .controlSize(.small)
                .accessibilityIdentifier("smoke.openCollectionButton")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityIdentifier("smoke.detectedCollectionBanner")
        }
    }
}
