import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            Text("Browse").tabItem { Label("Browse", systemImage: "globe") }
            Text("Library").tabItem { Label("Library", systemImage: "books.vertical") }
            Text("Settings").tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
