import SwiftUI
import MonoriCore

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var activeKind: SourceKind = .patreon
    @State private var isPickerExpanded = false

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
        default: return env.browse
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sourcePicker
            WebCollectionBanner(model: activeModel)
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
                        .tint(Color.accentColor)
                }
            }
        }
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
        default: model = env.browse
        }
        if model.currentURL == nil {
            model.load(SourceRegistry.provider(for: kind).startURL)
        }
    }

    private var sourcePicker: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isPickerExpanded.toggle()
                }
            } label: {
                HStack {
                    SourceGlyph(kind: activeKind)
                        .frame(width: 20, height: 20)
                    Text(SourceRegistry.provider(for: activeKind).displayName)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    DropdownChevron()
                        .stroke(.secondary, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 12, height: 12)
                        .rotationEffect(.degrees(isPickerExpanded ? 180 : 0))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("smoke.sourcePicker")

            if isPickerExpanded {
                ForEach(SourceRegistry.all.filter { $0.kind != activeKind }) { provider in
                    Divider().padding(.horizontal, 16)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            activeKind = provider.kind
                            ensureLoaded(provider.kind)
                            isPickerExpanded = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            SourceGlyph(kind: provider.kind)
                                .frame(width: 18, height: 18)
                            Text(provider.displayName)
                                .font(.subheadline)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("smoke.sourceEntry.\(provider.kind.rawValue)")
                }
            }
        }
        .clipped()
        .background(.bar)
    }
}
