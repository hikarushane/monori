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
    enum AppTab: Hashable { case browse, library, settings }

    @State private var env: AppEnvironment
    @State private var selectedTab = AppTab.library

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

            VStack(spacing: 0) {
                ZStack {
                    BrowseView()
                        .opacity(selectedTab == .browse ? 1 : 0)
                        .allowsHitTesting(selectedTab == .browse)
                    LibraryView()
                        .opacity(selectedTab == .library ? 1 : 0)
                        .allowsHitTesting(selectedTab == .library)
                    SettingsView()
                        .opacity(selectedTab == .settings ? 1 : 0)
                        .allowsHitTesting(selectedTab == .settings)
                }
                .clipped()
                .background(MonoriPalette.canvas)

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
        NativeTabBarView(
            selectedTab: tabSelection,
            isRegularWidth: metrics.isRegularWidth,
            contentPadding: metrics.contentHorizontalPadding
        )
        .frame(height: height)
        .padding(.bottom, bottomInset)
        .background {
            MonoriPalette.canvas
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }
}

#if DEBUG
#Preview("AppRoot") {
    AppRootView(env: PreviewSupport.sampleLibraryEnvironment())
}
#endif
