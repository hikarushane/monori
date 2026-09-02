import SwiftUI

enum AppChromeMetrics {
    static func bottomNavigationHeight(for viewHeight: CGFloat, isRegularWidth: Bool) -> CGFloat {
        isRegularWidth ? 123 : min(max(viewHeight * 0.09, 70), 90)
    }
}

private struct BottomNavigationHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 64
}

extension EnvironmentValues {
    var bottomNavigationHeight: CGFloat {
        get { self[BottomNavigationHeightKey.self] }
        set { self[BottomNavigationHeightKey.self] = newValue }
    }
}

struct AppRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private enum AppTab: Hashable { case browse, library, settings }

    @State private var env: AppEnvironment
    @State private var selectedTab = AppTab.browse

    init() { _env = State(initialValue: AppEnvironment()) }

    #if DEBUG
    init(env: AppEnvironment) { _env = State(initialValue: env) }
    #endif

    var body: some View {
        GeometryReader { proxy in
            let metrics = MonoriUIMetrics(horizontalSizeClass: horizontalSizeClass)
            let tabBarHeight = AppChromeMetrics.bottomNavigationHeight(
                for: proxy.size.height,
                isRegularWidth: metrics.isRegularWidth
            )

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
            .background(MonoriPalette.canvas)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                tabBar(height: tabBarHeight, bottomInset: proxy.safeAreaInsets.bottom,
                       metrics: metrics)
            }
            .preferredColorScheme(env.appPrefs.appearance.colorScheme)
            .tint(MonoriPalette.ink)
            .environment(\.bottomNavigationHeight, tabBarHeight)
            .environment(\.monoriUIMetrics, metrics)
            .environment(env)
            .modelContainer(env.store.container)
            .task { env.startSmokeToolsIfNeeded() }
            #if DEBUG
            .fullScreenCover(item: Binding(
                get: { env.autopilotReaderTarget },
                set: { env.autopilotReaderTarget = $0 })) { target in
                ReaderView(chapter: target.chapter)
                    .preferredColorScheme(env.appPrefs.appearance.colorScheme)
                    .environment(\.monoriUIMetrics, metrics)
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

    private func tabBar(height: CGFloat, bottomInset: CGFloat,
                        metrics: MonoriUIMetrics) -> some View {
        GeometryReader { proxy in
            let iconSize = metrics.isRegularWidth
                ? CGFloat(39)
                : min(max(proxy.size.height * 0.28, 24), 30)

            HStack(spacing: 0) {
                tabButton(.browse, title: "瀏覽", icon: MonoriTabIcon.browse,
                          identifier: "smoke.browseTab", iconSize: iconSize)
                tabButton(.library, title: "書庫", icon: MonoriTabIcon.library,
                          identifier: "smoke.libraryTab", iconSize: iconSize)
                tabButton(.settings, title: "設定", icon: MonoriTabIcon.settings,
                          identifier: "smoke.settingsTab", iconSize: iconSize)
            }
            .padding(.horizontal, metrics.contentHorizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: height + bottomInset)
        .background(MonoriPalette.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: AppTab, title: String, icon: Image,
                           identifier: String, iconSize: CGFloat) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            tabSelection.wrappedValue = tab
        } label: {
            VStack(spacing: MonoriSpacing.x1) {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(isSelected ? MonoriPalette.navigationAccent : MonoriPalette.secondaryInk)
                Text(title)
                    .font(MonoriTypography.ui(
                        horizontalSizeClass == .regular ? 20 : 11,
                        relativeTo: .caption2,
                                               weight: isSelected ? .semibold : .medium))
                    .tracking(MonoriTypography.navigationTracking)
                    .foregroundStyle(isSelected ? MonoriPalette.ink : MonoriPalette.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview("AppRoot") {
    AppRootView(env: PreviewSupport.sampleLibraryEnvironment())
}
#endif
