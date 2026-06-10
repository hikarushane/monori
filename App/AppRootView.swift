import SwiftUI

struct AppRootView: View {
    @State private var env = AppEnvironment()

    var body: some View {
        TabView {
            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
            Text("Library")
                .tabItem { Label("Library", systemImage: "books.vertical") }
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(env)
    }
}
