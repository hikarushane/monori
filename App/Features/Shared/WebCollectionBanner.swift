import SwiftUI
import MonoriCore
import os

private let bannerLog = Logger(subsystem: "dev.monori", category: "smoke-diagnostics")

/// Banner shown above a Patreon web view. On a collection page it offers
/// chapter import; on a post that links to a collection it shows the series
/// name with a shortcut to open that collection. Used by both the Browse tab
/// and the reader.
///
/// The post-import confirmation popup itself (`ImportConfirmationOverlay`) is
/// rendered by the caller (BrowseView / ReaderView), anchored to their own
/// full-screen root — a `.overlay` attached to this banner would only cover
/// the banner's own frame (which can be a collapsed/near-zero size outside a
/// collection page), not the whole screen. This view only owns the trigger.
struct WebCollectionBanner: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.monoriUIMetrics) private var metrics
    let model: WebViewModel
    @Binding var showImportConfirmation: Bool
    @State private var importing = false

    var body: some View {
        banner
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
            HStack(spacing: metrics.spacing.x2) {
                SourceGlyph(kind: kind)
                    .frame(width: metrics.accessoryIconSize, height: metrics.accessoryIconSize)
                Text(title)
                    .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                               relativeTo: .subheadline, weight: .medium))
                    .tracking(MonoriTypography.uiTracking)
                    .lineLimit(1)
                    .foregroundStyle(MonoriPalette.ink)
                Spacer(minLength: metrics.spacing.x2)
                Button(action: action) {
                    Text(importing ? progressLabel : "匯入")
                        .font(MonoriTypography.ui(metrics.buttonLabelFontSize,
                                                   relativeTo: .footnote, weight: .semibold))
                        .tracking(MonoriTypography.uiTracking)
                        .foregroundStyle(MonoriPalette.ink)
                        .padding(.horizontal, metrics.spacing.x2)
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
            HStack(spacing: metrics.spacing.x2) {
                Text("系列：\(title)")
                    .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                               relativeTo: .subheadline, weight: .medium))
                    .tracking(MonoriTypography.uiTracking)
                    .lineLimit(1)
                    .foregroundStyle(MonoriPalette.ink)
                Spacer(minLength: metrics.spacing.x2)
                Button(action: action) {
                    Text("開啟收藏")
                        .font(MonoriTypography.ui(metrics.buttonLabelFontSize,
                                                   relativeTo: .footnote, weight: .semibold))
                        .tracking(MonoriTypography.uiTracking)
                        .foregroundStyle(MonoriPalette.ink)
                        .padding(.horizontal, metrics.spacing.x2)
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
        VStack(alignment: .leading, spacing: metrics.spacing.x1, content: content)
            .padding(.horizontal, metrics.contentHorizontalPadding)
            .padding(.vertical, metrics.spacing.x2)
            .background(MonoriPalette.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MonoriPalette.divider)
                    .frame(height: 1)
            }
    }
}

/// Full-screen confirmation modal shown after a chapter import attempt.
/// Replaces the system `.alert` with a custom Washi White card over a
/// charcoal scrim, matching the Uguisu Zen "已匯入章節" design.
///
/// Mounted by the caller (BrowseView / ReaderView) as a `.overlay` on their
/// own full-screen root — see the note on `WebCollectionBanner` above.
struct ImportConfirmationOverlay: View {
    let importedCount: Int
    let onConfirm: () -> Void
    @Environment(\.monoriUIMetrics) private var metrics

    private var title: String {
        importedCount == 0 ? "未找到章節" : "已匯入章節"
    }

    private var message: String {
        importedCount == 0
            ? "此頁面未找到章節連結。請確認收藏頁面已完全載入後再試一次。"
            : "已匯入 \(importedCount) 個章節。已匯入的章節會合併，不會重複。"
    }

    /// Tailwind's `bg-charcoal/20` (#333333 @ 20%). Not a DESIGN.md palette
    /// role (Sumi Ink is the closest existing near-black), so it is kept as
    /// a scoped literal here rather than added as a new global token.
    private var scrim: Color {
        Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255).opacity(0.2)
    }

    var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Image("LaunchMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: metrics.emptyStateIconSize,
                           height: metrics.emptyStateIconSize)
                    .accessibilityHidden(true)
                    .padding(.bottom, MonoriSpacing.x2)

                Text(title)
                    .font(MonoriTypography.ui(metrics.emptyStateTitleFontSize,
                                               relativeTo: .title2, weight: .medium))
                    .foregroundStyle(MonoriPalette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, MonoriSpacing.x1)

                Text(message)
                    .font(MonoriTypography.ui(metrics.emptyStateDescriptionFontSize,
                                               relativeTo: .body))
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, MonoriSpacing.x3)

                Button(action: onConfirm) {
                    Text("確定")
                        .font(MonoriTypography.ui(metrics.buttonLabelFontSize,
                                                   relativeTo: .body, weight: .bold))
                        .foregroundStyle(MonoriPalette.canvas)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(MonoriPalette.brandAccent,
                                    in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                }
                .buttonStyle(ImportConfirmButtonStyle())
                .accessibilityLabel("確定")
            }
            .padding(metrics.spacing.x3)
            .frame(maxWidth: metrics.isRegularWidth ? 420 : 320)
            .background(MonoriPalette.canvas)
            .overlay {
                RoundedRectangle(cornerRadius: MonoriRadius.container)
                    .stroke(MonoriPalette.divider, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: MonoriRadius.container))
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .padding(.horizontal, MonoriSpacing.x4)
        }
    }
}

private struct ImportConfirmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
