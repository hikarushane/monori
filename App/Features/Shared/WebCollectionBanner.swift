import SwiftUI
import MonoriCore
import os

private let bannerLog = Logger(subsystem: "dev.monori", category: "smoke-diagnostics")

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
            .alert(env.importedCountThisSession == 0 ? "未找到章節" : "已匯入章節",
                   isPresented: $showImportConfirmation) {
                Button("確定") {}
            } message: {
                if env.importedCountThisSession == 0 {
                    Text("此頁面未找到章節連結。請確認收藏頁面已完全載入後再試一次。Patreon 的頁面結構也可能已變更。")
                } else {
                    Text("已匯入 \(env.importedCountThisSession) 個章節。已匯入的章節會合併，不會重複。")
                }
            }
    }

    @ViewBuilder
    private var banner: some View {
        if model.isOnAO3WorkPage {
            HStack {
                HStack(spacing: 6) {
                    SourceGlyph(kind: .ao3).frame(width: 16, height: 16)
                    Text(model.detectedCollection?.collectionName ?? "AO3 作品")
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    importing = true
                    env.importedCountThisSession = 0
                    Task {
                        _ = await env.importAO3Work(from: model)
                        importing = false
                        showImportConfirmation = true
                    }
                } label: {
                    if importing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            if env.ao3ImportTotal > 0 {
                                Text("匯入中 \(env.ao3ImportCurrent)/\(env.ao3ImportTotal)⋯")
                            } else {
                                Text("匯入中⋯")
                            }
                        }
                    } else {
                        Text("匯入")
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
        } else if model.isOnGoogleDocPage {
            HStack {
                Label("Google 文件", systemImage: "doc.richtext")
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
                        HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("匯入中⋯") }
                    } else {
                        Text("匯入")
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
                Label("收藏頁面", systemImage: "books.vertical")
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
                            Text("匯入中⋯")
                        }
                    } else {
                        Text("匯入")
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
                Text("系列：\(link.collectionName)")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Button("開啟收藏") {
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
