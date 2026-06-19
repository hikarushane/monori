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
    @State private var importing = false

    var body: some View {
        banner
            .alert(env.importedCountThisSession == 0 ? "No chapters found" : "Chapters imported",
                   isPresented: $showImportConfirmation) {
                Button("OK") {}
            } message: {
                if env.importedCountThisSession == 0 {
                    Text("No chapter links were found on this page. Make sure the collection page finished loading, then try again. Patreon's markup may also have changed.")
                } else {
                    Text("Imported \(env.importedCountThisSession) chapters. Already-imported chapters are merged, not duplicated.")
                }
            }
    }

    @ViewBuilder
    private var banner: some View {
        if model.isOnGoogleDocPage {
            HStack {
                Label("Google Doc", systemImage: "doc.richtext")
                    .font(.subheadline)
                Spacer()
                Button {
                    importing = true
                    env.importedCountThisSession = 0
                    Task {
                        _ = await env.importGoogleDoc(from: model)
                        importing = false
                        showImportConfirmation = true
                    }
                } label: {
                    if importing {
                        HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Importing…") }
                    } else {
                        Text("Import")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(importing)
                .accessibilityIdentifier("smoke.importChaptersButton")
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
            .accessibilityIdentifier("smoke.collectionBanner")
        } else if model.isOnCollectionPage {
            HStack {
                Label("Collection page", systemImage: "books.vertical")
                    .font(.subheadline)
                Spacer()
                Button {
                    importing = true
                    env.importedCountThisSession = 0
                    Task {
                        await model.runCollectionImport()
                        // applyImport flushes 300ms after the last chapter
                        // message lands; wait it out before reading the count.
                        try? await Task.sleep(for: .milliseconds(500))
                        if AppEnvironment.isSmokeMode && env.importedCountThisSession == 0 {
                            bannerLog.notice("[SMOKE] Import found 0 chapters — dumping page structure")
                            model.dumpPageLinks { dump in
                                for line in dump.split(separator: "\n") {
                                    bannerLog.notice("[SMOKE] \(String(line), privacy: .public)")
                                }
                            }
                        }
                        importing = false
                        showImportConfirmation = true
                    }
                } label: {
                    if importing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Importing…")
                        }
                    } else {
                        Text("Import all chapters")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(importing)
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
