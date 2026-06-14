import SwiftUI
import ChapterlyCore

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: 0) {
            WebCollectionBanner(model: env.browse)
            PatreonWebView(model: env.browse, allowBackSwipe: {
                BackSwipePolicy.browseDecision(currentURL: env.browse.currentURL,
                                               canGoBack: env.browse.webView.canGoBack) == .goBack
            })
                .overlay(alignment: .top) {
                    if env.browse.loadingProgress < 1 {
                        ProgressView(value: env.browse.loadingProgress)
                            .progressViewStyle(.linear)
                    }
                }
        }
        .onAppear {
            if env.browse.currentURL == nil {
                env.browse.load(URL(string: "https://www.patreon.com/home")!)
            }
        }
    }
}
