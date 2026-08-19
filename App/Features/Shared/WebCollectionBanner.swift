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
                    Text("此頁面未找到章節連結。請確認收藏頁面已完全載入後再試一次。")
                } else {
                    Text("已匯入 \(env.importedCountThisSession) 個章節。已匯入的章節會合併，不會重複。")
                }
            }
    }

    @ViewBuilder
    private var banner: some View {
        if model.isOnAO3WorkPage {
            importBanner(kind: .ao3,
                         title: model.detectedCollection?.collectionName ?? "AO3 作品",
                         progressLabel: ao3ProgressLabel) {
                    importing = true
                    env.importedCountThisSession = 0
                    Task {
                        _ = await env.importAO3Work(from: model)
                        importing = false
                        showImportConfirmation = true
                    }
            }
        } else if model.isOnVocusRoomPage {
            importBanner(kind: .vocus,
                         title: model.detectedCollection?.collectionName ?? "Vocus 房間") {
                    importing = true
                    env.importedCountThisSession = 0
                    Task {
                        _ = await env.importVocusRoom(from: model)
                        importing = false
                        showImportConfirmation = true
                    }
            }
        } else if model.isOnAFFForewordPage {
            importBanner(kind: .asianFanfics,
                         title: model.detectedCollection?.collectionName ?? "AFF 故事") {
                    importing = true
                    env.importedCountThisSession = 0
                    Task {
                        _ = await env.importAFFStory(from: model)
                        importing = false
                        showImportConfirmation = true
                    }
            }
        } else if model.isOnGoogleDocPage {
            importBanner(kind: .googleDocs, title: "Google 文件") {
                    importing = true
                    env.importedCountThisSession = 0
                    Task {
                        _ = await env.importGoogleDoc(from: model)
                        importing = false
                        showImportConfirmation = true
                    }
            }
        } else if model.isOnCollectionPage {
            importBanner(kind: .patreon, title: "收藏頁面") {
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
            }
        } else if let link = model.detectedCollection {
            collectionBanner(title: link.collectionName) {
                    if let url = URLNormalizer.normalize(link.collectionURL) {
                        model.load(url)
                    }
                }
        }
    }

    private var ao3ProgressLabel: String {
        env.ao3ImportTotal > 0
            ? "匯入中 \(env.ao3ImportCurrent)/\(env.ao3ImportTotal)"
            : "匯入中"
    }

    private func importBanner(kind: SourceKind, title: String,
                              progressLabel: String = "匯入中",
                              action: @escaping () -> Void) -> some View {
        bannerContainer {
            HStack(spacing: MonoriSpacing.x2) {
                SourceGlyph(kind: kind)
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .medium))
                    .tracking(MonoriTypography.uiTracking)
                    .lineLimit(1)
                    .foregroundStyle(MonoriPalette.ink)
                Spacer(minLength: MonoriSpacing.x2)
                Button(action: action) {
                    Text(importing ? progressLabel : "匯入")
                        .font(MonoriTypography.ui(13, relativeTo: .footnote, weight: .semibold))
                        .tracking(MonoriTypography.uiTracking)
                        .foregroundStyle(MonoriPalette.ink)
                        .padding(.horizontal, MonoriSpacing.x2)
                        .frame(minHeight: 40)
                        .background(MonoriPalette.canvas,
                                    in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: MonoriRadius.control)
                                .stroke(MonoriPalette.ink, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(importing)
                .opacity(importing ? 0.7 : 1)
                .accessibilityIdentifier("smoke.importChaptersButton")
            }
            if importing {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(MonoriPalette.highlight)
            }
        }
        .accessibilityIdentifier("smoke.collectionBanner")
    }

    private func collectionBanner(title: String, action: @escaping () -> Void) -> some View {
        bannerContainer {
            HStack(spacing: MonoriSpacing.x2) {
                Text("系列：\(title)")
                    .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .medium))
                    .tracking(MonoriTypography.uiTracking)
                    .lineLimit(1)
                    .foregroundStyle(MonoriPalette.ink)
                Spacer(minLength: MonoriSpacing.x2)
                Button(action: action) {
                    Text("開啟收藏")
                        .font(MonoriTypography.ui(13, relativeTo: .footnote, weight: .semibold))
                        .tracking(MonoriTypography.uiTracking)
                        .foregroundStyle(MonoriPalette.ink)
                        .padding(.horizontal, MonoriSpacing.x2)
                        .frame(minHeight: 40)
                        .background(MonoriPalette.canvas,
                                    in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: MonoriRadius.control)
                                .stroke(MonoriPalette.ink, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("smoke.openCollectionButton")
            }
        }
        .accessibilityIdentifier("smoke.detectedCollectionBanner")
    }

    private func bannerContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MonoriSpacing.x1, content: content)
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.vertical, MonoriSpacing.x2)
            .background(MonoriPalette.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MonoriPalette.divider)
                    .frame(height: 1)
            }
    }
}
