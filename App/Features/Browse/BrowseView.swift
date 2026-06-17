import SwiftUI
import ChapterlyCore

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var activeKind: SourceKind = .patreon

    var body: some View {
        VStack(spacing: 0) {
            sourcePicker
            WebCollectionBanner(model: env.browse)
            PatreonWebView(model: env.browse, allowBackSwipe: {
                BackSwipePolicy.browseDecision(currentURL: env.browse.currentURL,
                                               canGoBack: env.browse.webView.canGoBack) == .goBack
            })
            .overlay(alignment: .top) {
                if env.browse.loadingProgress < 1 {
                    ProgressView(value: env.browse.loadingProgress).progressViewStyle(.linear)
                }
            }
        }
        .onAppear {
            if env.browse.currentURL == nil {
                env.browse.load(SourceRegistry.patreon.startURL)
            }
        }
    }

    private var sourcePicker: some View {
        HStack(spacing: 8) {
            ForEach(SourceRegistry.all) { provider in
                Button {
                    activeKind = provider.kind
                    env.browse.load(provider.startURL)
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
