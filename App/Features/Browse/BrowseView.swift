import SwiftUI
import ChapterlyCore
import os

private let browseLog = Logger(subsystem: "dev.chapterly", category: "smoke-diagnostics")

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
                        if AppEnvironment.isSmokeMode && env.importedCountThisSession == 0 {
                            browseLog.notice("[SMOKE] Import found 0 chapters — dumping page structure")
                            env.browse.dumpPageLinks { dump in
                                for line in dump.split(separator: "\n") {
                                    browseLog.notice("[SMOKE] \(String(line), privacy: .public)")
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
                .accessibilityIdentifier("smoke.openCollectionButton")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityIdentifier("smoke.detectedCollectionBanner")
        }
    }
}
