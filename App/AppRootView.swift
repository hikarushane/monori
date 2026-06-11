import SwiftUI

struct AppRootView: View {
    @State private var env = AppEnvironment()

    var body: some View {
        TabView {
            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
                .accessibilityIdentifier("smoke.browseTab")
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .accessibilityIdentifier("smoke.libraryTab")
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .accessibilityIdentifier("smoke.settingsTab")
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
