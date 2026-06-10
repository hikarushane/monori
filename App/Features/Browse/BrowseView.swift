import SwiftUI

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        PatreonWebView(model: env.browse)
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                if env.browse.currentURL == nil {
                    env.browse.load(URL(string: "https://www.patreon.com/home")!)
                }
            }
    }
}
