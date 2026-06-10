import SwiftUI

struct AppRootView: View {
    @State private var env = AppEnvironment()

    var body: some View {
        TabView {
            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(env)
        .modelContainer(env.store.container)
    }
}
