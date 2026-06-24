import SwiftUI

struct AppRootView: View {
    private enum AppTab: Hashable { case browse, library, settings }

    @State private var env = AppEnvironment()
    @State private var selectedTab = AppTab.browse

    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .browse, selectedTab == .browse {
                    env.browse.handleBrowseTabReselect()
                }
                selectedTab = newTab
            })) {
            BrowseView()
                .tabItem { Label { Text("瀏覽") } icon: { MonoriTabIcon.browse } }
                .accessibilityIdentifier("smoke.browseTab")
                .tag(AppTab.browse)
            LibraryView()
                .tabItem { Label { Text("書庫") } icon: { MonoriTabIcon.library } }
                .accessibilityIdentifier("smoke.libraryTab")
                .tag(AppTab.library)
            SettingsView()
                .tabItem { Label { Text("設定") } icon: { MonoriTabIcon.settings } }
                .accessibilityIdentifier("smoke.settingsTab")
                .tag(AppTab.settings)
        }
        .environment(env)
        .modelContainer(env.store.container)
        .task { env.startSmokeToolsIfNeeded() }
        #if DEBUG
        .fullScreenCover(item: Binding(
            get: { env.autopilotReaderTarget },
            set: { env.autopilotReaderTarget = $0 })) { target in
            ReaderView(chapter: target.chapter)
                .environment(env)
                .modelContainer(env.store.container)
        }
        #endif
    }
}
