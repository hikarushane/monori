import SwiftUI
import ChapterlyCore

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: 0) {
            WebCollectionBanner(model: env.browse)
            PatreonWebView(model: env.browse)
        }
        .onAppear {
            if env.browse.currentURL == nil {
                env.browse.load(URL(string: "https://www.patreon.com/home")!)
            }
        }
    }
}
