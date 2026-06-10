import SwiftUI
import ChapterlyCore

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
                        showImportConfirmation = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
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
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}
