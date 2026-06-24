import SwiftUI
import MonoriCore

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var activeKind: SourceKind = .patreon

    /// The web view shown for the selected source. Each source owns a distinct
    /// WebViewModel -- and thus a distinct WKWebView and back/forward history --
    /// so navigating or back-swiping inside one source can never cross into the
    /// other. `.patreon` -> `env.browse`; `.googleDocs` -> `env.googleBrowse`.
    private var activeModel: WebViewModel {
        activeKind == .googleDocs ? env.googleBrowse : env.browse
    }

    var body: some View {
        VStack(spacing: 0) {
            sourcePicker
            WebCollectionBanner(model: activeModel)
            PatreonWebView(model: activeModel, allowBackSwipe: {
                BackSwipePolicy.browseDecision(currentURL: activeModel.currentURL,
                                               canGoBack: activeModel.webView.canGoBack) == .goBack
            })
            // Force a fresh representable (and makeUIView) when the source flips,
            // so the displayed WKWebView swaps to the active model's web view.
            .id(activeKind)
            .overlay(alignment: .top) {
                if activeModel.loadingProgress < 1 {
                    ProgressView(value: activeModel.loadingProgress)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                }
            }
        }
        .onAppear { ensureLoaded(activeKind) }
    }

    /// Loads a source's start page the first time it is shown. A source the user
    /// already visited keeps its place (no reload) when switched back to.
    private func ensureLoaded(_ kind: SourceKind) {
        let model = kind == .googleDocs ? env.googleBrowse : env.browse
        if model.currentURL == nil {
            model.load(SourceRegistry.provider(for: kind).startURL)
        }
    }

    private var sourcePicker: some View {
        HStack(spacing: 8) {
            ForEach(SourceRegistry.all) { provider in
                Button {
                    activeKind = provider.kind
                    ensureLoaded(provider.kind)
                } label: {
                    Label(provider.displayName, systemImage: provider.iconSystemName)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(activeKind == provider.kind ? .accentColor : .secondary)
                .accessibilityIdentifier("smoke.sourceEntry.\(provider.kind.rawValue)")
            }
        }
        .padding(.horizontal).padding(.vertical, 6)
        .background(.bar)
    }
}
