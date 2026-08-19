import SwiftUI

struct AppRootView: View {
    private enum AppTab: Hashable { case browse, library, settings }

    @State private var env = AppEnvironment()
    @State private var selectedTab = AppTab.browse

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: tabSelection) {
                BrowseView()
                    .tabItem { Label { Text("瀏覽") } icon: { MonoriTabIcon.browse } }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppTab.browse)
                LibraryView()
                    .tabItem { Label { Text("書庫") } icon: { MonoriTabIcon.library } }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppTab.library)
                SettingsView()
                    .tabItem { Label { Text("設定") } icon: { MonoriTabIcon.settings } }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppTab.settings)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 64)
            }
            .overlay(alignment: .bottom) {
                tabBar(bottomInset: proxy.safeAreaInsets.bottom)
            }
            .preferredColorScheme(env.appPrefs.appearance.colorScheme)
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
        .ignoresSafeArea(edges: .bottom)
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .browse, selectedTab == .browse {
                    env.browse.handleBrowseTabReselect()
                }
                selectedTab = newTab
            })
    }

    private func tabBar(bottomInset: CGFloat) -> some View {
        GeometryReader { proxy in
            let iconSize = min(max(proxy.size.height * 0.28, 24), 30)

            HStack(spacing: 0) {
                tabButton(.browse, title: "瀏覽", icon: MonoriTabIcon.browse,
                          identifier: "smoke.browseTab", iconSize: iconSize)
                tabButton(.library, title: "書庫", icon: MonoriTabIcon.library,
                          identifier: "smoke.libraryTab", iconSize: iconSize)
                tabButton(.settings, title: "設定", icon: MonoriTabIcon.settings,
                          identifier: "smoke.settingsTab", iconSize: iconSize)
            }
            .frame(width: proxy.size.width * 0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 64 + bottomInset)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
    }

    private func tabButton(_ tab: AppTab, title: String, icon: Image,
                           identifier: String, iconSize: CGFloat) -> some View {
        Button {
            tabSelection.wrappedValue = tab
        } label: {
            VStack(spacing: 4) {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}
