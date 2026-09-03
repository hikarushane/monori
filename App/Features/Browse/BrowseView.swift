import SwiftUI
import MonoriCore

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.monoriUIMetrics) private var metrics
    @Environment(\.bottomNavigationHeight) private var bottomNavigationHeight
    @State private var activeKind: SourceKind
    @State private var isPickerExpanded = false
    @State private var showImportConfirmation = false

    init() {
        let stored = UserDefaults.standard.string(forKey: "app.browseDefaultSource")
            ?? SourceKind.patreon.rawValue
        _activeKind = State(initialValue: SourceKind(rawValue: stored) ?? .patreon)
    }

    /// The web view shown for the selected source. Each source owns a distinct
    /// WebViewModel -- and thus a distinct WKWebView and back/forward history --
    /// so navigating or back-swiping inside one source can never cross into the
    /// other. `.patreon` -> `env.browse`; `.googleDocs` -> `env.googleBrowse`.
    private var activeModel: WebViewModel {
        switch activeKind {
        case .googleDocs: return env.googleBrowse
        case .ao3: return env.ao3Browse
        case .vocus: return env.vocusBrowse
        case .asianFanfics: return env.affBrowse
        case .cxc: return env.cxcBrowse
        case .slashtw: return env.slashtwBrowse
        default: return env.browse
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sourcePicker
            WebCollectionBanner(model: activeModel, showImportConfirmation: $showImportConfirmation)
            PatreonWebView(model: activeModel,
                           allowBackSwipe: {
                BackSwipePolicy.browseDecision(currentURL: activeModel.currentURL,
                                               canGoBack: activeModel.webView.canGoBack) == .goBack
            }, enablePullToRefresh: true)
            // Force a fresh representable (and makeUIView) when the source flips,
            // so the displayed WKWebView swaps to the active model's web view.
            .id(activeKind)
            // Cross-fade the old and new web view when the user switches sources.
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: activeKind)
            .overlay(alignment: .top) {
                if activeModel.loadingProgress < 1 {
                    ProgressView(value: activeModel.loadingProgress)
                        .progressViewStyle(.linear)
                        .tint(MonoriPalette.highlight)
                }
            }
        }
        .padding(.bottom, bottomNavigationHeight)
        .overlay {
            if showImportConfirmation {
                ImportConfirmationOverlay(importedCount: env.importedCountThisSession) {
                    showImportConfirmation = false
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showImportConfirmation)
        .onAppear { ensureLoaded(activeKind) }
        .sheet(isPresented: Binding(
            get: { activeModel.popupWebView != nil },
            set: { if !$0 { activeModel.popupWebView = nil } }
        )) {
            PopupWebSheet(webView: activeModel.popupWebView!)
        }
    }

    /// Loads a source's start page the first time it is shown. A source the user
    /// already visited keeps its place (no reload) when switched back to.
    private func ensureLoaded(_ kind: SourceKind) {
        let model: WebViewModel
        switch kind {
        case .googleDocs: model = env.googleBrowse
        case .ao3: model = env.ao3Browse
        case .vocus: model = env.vocusBrowse
        case .asianFanfics: model = env.affBrowse
        case .cxc: model = env.cxcBrowse
        case .slashtw: model = env.slashtwBrowse
        default: model = env.browse
        }
        if model.currentURL == nil {
            model.load(SourceRegistry.provider(for: kind).startURL)
        }
    }

    private var sourcePicker: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isPickerExpanded.toggle()
                }
            } label: {
                HStack(spacing: metrics.spacing.x2) {
                    SourceGlyph(kind: activeKind)
                        .frame(width: metrics.actionIconSize, height: metrics.actionIconSize)
                    Text(SourceRegistry.provider(for: activeKind).displayName)
                        .font(MonoriTypography.ui(metrics.buttonLabelFontSize,
                                                   relativeTo: .subheadline, weight: .semibold))
                        .tracking(MonoriTypography.uiTracking)
                    Spacer()
                    DropdownChevron()
                        .stroke(MonoriPalette.secondaryInk,
                                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: metrics.accessoryIconSize, height: metrics.accessoryIconSize)
                        .rotationEffect(.degrees(isPickerExpanded ? 180 : 0))
                }
                .foregroundStyle(MonoriPalette.ink)
                .padding(.horizontal, metrics.contentHorizontalPadding)
                .padding(.vertical, metrics.spacing.x2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("smoke.sourcePicker")

            if isPickerExpanded {
                ForEach(SourceRegistry.all.filter { $0.kind != activeKind }) { provider in
                    Rectangle()
                        .fill(MonoriPalette.divider)
                        .frame(height: 1)
                        .padding(.horizontal, MonoriSpacing.x3)
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            activeKind = provider.kind
                            ensureLoaded(provider.kind)
                            isPickerExpanded = false
                        }
                    } label: {
                        HStack(spacing: metrics.spacing.x2) {
                            SourceGlyph(kind: provider.kind)
                                .frame(width: metrics.accessoryIconSize,
                                       height: metrics.accessoryIconSize)
                            Text(provider.displayName)
                                .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                                           relativeTo: .subheadline, weight: .medium))
                                .tracking(MonoriTypography.uiTracking)
                            Spacer()
                        }
                        .foregroundStyle(MonoriPalette.secondaryInk)
                        .padding(.horizontal, metrics.contentHorizontalPadding)
                        .padding(.vertical, metrics.spacing.x2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .accessibilityIdentifier("smoke.sourceEntry.\(provider.kind.rawValue)")
                }
            }
        }
        .clipped()
        .background(MonoriPalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }
}
