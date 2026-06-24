import SwiftUI
import MonoriCore

// MARK: - Source Icons

/// Patreon brand mark: vertical bar + circle (simplified P shape).
struct PatreonMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: w * 0.12, y: h * 0.2, width: w * 0.24, height: h * 0.6),
            cornerSize: CGSize(width: w * 0.06, height: w * 0.06))
        path.addEllipse(in: CGRect(x: w * 0.44, y: h * 0.2, width: w * 0.42, height: w * 0.42))
        return path
    }
}

/// Google Drive mark: outlined triangle.
struct DriveMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.93, y: h * 0.8))
        path.addLine(to: CGPoint(x: w * 0.07, y: h * 0.8))
        path.closeSubpath()
        return path
    }
}

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
                    HStack(spacing: 6) {
                        sourceIcon(for: provider.kind)
                            .frame(width: 16, height: 16)
                        Text(provider.displayName)
                            .font(.subheadline)
                    }
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

    @ViewBuilder
    private func sourceIcon(for kind: SourceKind) -> some View {
        switch kind {
        case .patreon:
            PatreonMark().fill(.foreground)
        case .googleDocs:
            DriveMark().stroke(.foreground, lineWidth: 1.5)
        }
    }
}
