import SwiftUI
import SwiftData
import MonoriCore

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bottomNavigationHeight) private var bottomNavigationHeight
    @Query private var allCollections: [LocalCollectionModel]
    @State private var sortOrder: LibrarySortOrder = .title
    @State private var searchText = ""
    @State private var sourceFilter: SourceKind?
    @State private var showsSearch = false
    @State private var showsSortMenu = false
    @State private var revealedCollectionID: String?

    private var collections: [LocalCollectionModel] {
        LibraryQuery.apply(allCollections, sort: sortOrder,
                           searchText: searchText, status: nil)
            .filter { sourceFilter == nil || $0.sourceKind == sourceFilter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allCollections.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .background(MonoriPalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { libraryHeader }
            .sheet(isPresented: $showsSearch) {
                LibrarySearchSheet(allCollections: allCollections,
                                   searchText: $searchText)
            }
            .overlay {
                if showsSortMenu {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showsSortMenu = false
                            }
                        }
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsSortMenu {
                    sortDropdown
                        .padding(.top, MonoriSpacing.x1)
                        .padding(.trailing, MonoriSpacing.x3)
                        .transition(.scale(scale: 0.95, anchor: .topTrailing)
                            .combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) { runningOverlay }
            .task { env.autoCheck.runIfDue() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { env.autoCheck.runIfDue() }
            }
            .onDisappear { env.autoCheck.cancel() }
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
            HStack(alignment: .firstTextBaseline) {
                Text("書庫")
                    .font(MonoriTypography.ui(32, relativeTo: .largeTitle, weight: .bold))
                    .tracking(-0.6)

                Spacer()

                HStack(spacing: 18) {
                    Button {
                        showsSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(MonoriTypography.ui(20, relativeTo: .title3, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("搜尋書庫")
                    .accessibilityIdentifier("smoke.librarySearchButton")

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showsSortMenu.toggle()
                        }
                    } label: {
                        SortIcon()
                            .stroke(MonoriPalette.ink,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(width: 20, height: 20)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("書庫選項")
                    .accessibilityIdentifier("smoke.librarySortMenu")
                }
                .foregroundStyle(MonoriPalette.ink)
            }

            Text("共 \(allCollections.count) 部作品")
                .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .medium))
                .tracking(MonoriTypography.uiTracking)
                .foregroundStyle(MonoriPalette.secondaryInk)
                .accessibilityIdentifier("smoke.librarySummary")

            sourceFilterPicker
        }
        .padding(.horizontal, MonoriSpacing.x3)
        .padding(.top, MonoriSpacing.x3)
        .padding(.bottom, MonoriSpacing.x2)
        .background(MonoriPalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }

    private var sourceFilterPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MonoriSpacing.x1) {
                sourceFilterChip(nil, title: "全部")
                ForEach(SourceRegistry.all) { provider in
                    sourceFilterChip(provider.kind, title: provider.displayName)
                }
            }
            .padding(.vertical, MonoriSpacing.x1)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollIndicators(.hidden)
        .accessibilityLabel("來源篩選")
    }

    private func sourceFilterChip(_ kind: SourceKind?, title: String) -> some View {
        let isSelected = sourceFilter == kind
        return Button {
            sourceFilter = kind
        } label: {
            Text(title)
                .font(MonoriTypography.ui(14, relativeTo: .subheadline,
                                           weight: isSelected ? .semibold : .medium))
                .tracking(MonoriTypography.uiTracking)
                .foregroundStyle(MonoriPalette.ink)
                .lineLimit(1)
                .padding(.horizontal, MonoriSpacing.x2)
                .padding(.vertical, 10)
                .background(isSelected ? MonoriPalette.surface : MonoriPalette.canvas,
                            in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: MonoriRadius.control)
                        .stroke(isSelected ? MonoriPalette.ink : MonoriPalette.divider,
                                lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("來源：\(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var listContent: some View {
        List {
            ForEach(collections) { collection in
                NavigationLink(value: collection.id) {
                    row(collection)
                }
                .chapterSwipeActions(
                    itemID: collection.id,
                    revealedID: $revealedCollectionID,
                    onDelete: { env.store.deleteCollection(collection) }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: MonoriSpacing.x3,
                                           bottom: 0, trailing: MonoriSpacing.x3))
                .listRowBackground(MonoriPalette.canvas)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MonoriPalette.canvas)
        .listRowSeparatorTint(MonoriPalette.divider)
        .contentMargins(
            .bottom,
            bottomNavigationHeight + MonoriSpacing.x2,
            for: .scrollContent
        )
        .refreshable { await env.autoCheck.runForced() }
        .navigationDestination(for: String.self) { id in
            if let collection = allCollections.first(where: { $0.id == id }) {
                CollectionTOCView(collection: collection)
            }
        }
    }

    private var sortDropdown: some View {
        VStack(spacing: 0) {
            menuOptionRow("標題", selected: sortOrder == .title) { sortOrder = .title }
            menuGroupDivider()
            menuOptionRow("最近更新", selected: sortOrder == .recentlyUpdated) { sortOrder = .recentlyUpdated }
            menuGroupDivider()
            menuOptionRow("最近閱讀", selected: sortOrder == .recentlyRead) { sortOrder = .recentlyRead }
            menuGroupDivider()
            menuOptionRow("來源", selected: sortOrder == .source) { sortOrder = .source }
        }
        .background(MonoriPalette.surface,
                    in: RoundedRectangle(cornerRadius: MonoriRadius.container))
        .overlay {
            RoundedRectangle(cornerRadius: MonoriRadius.container)
                .stroke(MonoriPalette.divider, lineWidth: 1)
        }
        .frame(width: 200)
    }

    private func menuOptionRow(_ title: String, selected: Bool,
                               action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(.easeOut(duration: 0.15)) {
                showsSortMenu = false
            }
        } label: {
            HStack {
                Text(title)
                    .font(MonoriTypography.ui(16, relativeTo: .body,
                                              weight: selected ? .semibold : .regular))
                    .foregroundStyle(MonoriPalette.ink)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MonoriPalette.ink)
                }
            }
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.vertical, MonoriSpacing.x2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuGroupDivider() -> some View {
        Rectangle()
            .fill(MonoriPalette.divider)
            .frame(height: 1)
            .padding(.horizontal, MonoriSpacing.x3)
    }

    @ViewBuilder
    private var runningOverlay: some View {
        if env.autoCheck.isRunning {
            VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                Text("檢查新章節中 \(env.autoCheck.checkedCount)/\(env.autoCheck.totalCount)")
                    .font(MonoriTypography.ui(13, relativeTo: .footnote, weight: .medium))
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.ink)
                ProgressView()
                    .tint(MonoriPalette.highlight)
                    .progressViewStyle(.linear)
            }
            .padding(MonoriSpacing.x2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonoriPalette.surface,
                        in: RoundedRectangle(cornerRadius: MonoriRadius.container))
            .overlay {
                RoundedRectangle(cornerRadius: MonoriRadius.container)
                    .stroke(MonoriPalette.divider, lineWidth: 1)
            }
            .padding(.horizontal, MonoriSpacing.x3)
            .padding(.bottom, MonoriSpacing.x2)
            .accessibilityIdentifier("smoke.autoCheckSpinner")
        }
    }

    private func row(_ collection: LocalCollectionModel) -> some View {
        HStack(alignment: .center, spacing: MonoriSpacing.x2) {
            SourceGlyph(kind: collection.sourceKind)
                .frame(width: 22, height: 22)
                .foregroundStyle(MonoriPalette.secondaryInk)
                .frame(width: 28)
                .accessibilityIdentifier("smoke.collectionSourceIcon")
            VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                Text(collection.title)
                    .font(MonoriTypography.ui(17, relativeTo: .headline, weight: .semibold))
                    .foregroundStyle(MonoriPalette.ink)
                if let creator = collection.creatorName, !creator.isEmpty {
                    Text("作者：\(creator)")
                        .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                        .foregroundStyle(MonoriPalette.secondaryInk)
                }
                HStack(spacing: 6) {
                    Text("\(collection.chapters.count) 章")
                    if let updated = collection.lastNewChapterAt {
                        Text("・更新於 \(updated.formatted(.relative(presentation: .named).locale(Locale(identifier: "zh-Hant"))))")
                    }
                }
                .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                .foregroundStyle(MonoriPalette.secondaryInk)
            }
            Spacer()
            if env.autoCheck.needsLoginCollectionIDs.contains(collection.id) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .accessibilityLabel("需要登入")
            }
            if collection.unreadCount > 0 {
                Text("\(collection.unreadCount)")
                    .font(MonoriTypography.ui(11, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(MonoriPalette.ink)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(MonoriPalette.highlight,
                                in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                    .accessibilityIdentifier("smoke.libraryUnreadBadge")
                    .accessibilityLabel("\(collection.unreadCount) 個新章節")
            }
        }
        .padding(.vertical, MonoriSpacing.x2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
            Text("尚無收藏")
                .font(MonoriTypography.ui(24, relativeTo: .title2, weight: .semibold))
                .foregroundStyle(MonoriPalette.ink)
            Text("在「瀏覽」分頁開啟 Patreon 文章的系列頁面，然後點選「匯入」。")
                .font(MonoriTypography.ui(16, relativeTo: .body))
                .foregroundStyle(MonoriPalette.secondaryInk)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(MonoriSpacing.x3)
    }
}

private struct SortIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var p = Path()
        p.move(to: CGPoint(x: 17*s, y: 4*s))
        p.addLine(to: CGPoint(x: 17*s, y: 20*s))
        p.move(to: CGPoint(x: 17*s, y: 20*s))
        p.addLine(to: CGPoint(x: 13*s, y: 16*s))
        p.move(to: CGPoint(x: 17*s, y: 20*s))
        p.addLine(to: CGPoint(x: 21*s, y: 16*s))
        p.move(to: CGPoint(x: 7*s, y: 20*s))
        p.addLine(to: CGPoint(x: 7*s, y: 4*s))
        p.move(to: CGPoint(x: 7*s, y: 4*s))
        p.addLine(to: CGPoint(x: 3*s, y: 8*s))
        p.move(to: CGPoint(x: 7*s, y: 4*s))
        p.addLine(to: CGPoint(x: 11*s, y: 8*s))
        return p
    }
}

#if DEBUG
#Preview("書庫・有內容") {
    let env = PreviewSupport.sampleLibraryEnvironment()
    NavigationStack {
        LibraryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}

#Preview("書庫・空狀態") {
    let env = PreviewSupport.emptyEnvironment()
    NavigationStack {
        LibraryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}

#Preview("書庫・有未讀") {
    let env = PreviewSupport.unreadLibraryEnvironment()
    NavigationStack {
        LibraryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}

#Preview("書庫・大字體", traits: .fixedLayout(width: 430, height: 932)) {
    let env = PreviewSupport.sampleLibraryEnvironment()
    NavigationStack {
        LibraryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("書庫・壓力測試") {
    let env = PreviewSupport.stressEnvironment()
    NavigationStack {
        LibraryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}
#endif

private struct LibrarySearchSheet: View {
    let allCollections: [LocalCollectionModel]
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss

    private var results: [LocalCollectionModel] {
        LibraryQuery.apply(allCollections, sort: .title,
                           searchText: searchText, status: nil)
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    ContentUnavailableView.search
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(results) { collection in
                        Button {
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.title)
                                    .font(MonoriTypography.ui(17, relativeTo: .headline,
                                                              weight: .semibold))
                                if let creator = collection.creatorName, !creator.isEmpty {
                                    Text("作者：\(creator)")
                                        .font(MonoriTypography.ui(14, relativeTo: .subheadline))
                                        .foregroundStyle(MonoriPalette.secondaryInk)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(MonoriPalette.ink)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MonoriPalette.canvas)
            .listRowSeparatorTint(MonoriPalette.divider)
            .navigationTitle("搜尋書庫")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "書名或作者")
            .tint(MonoriPalette.ink)
            .toolbarBackground(MonoriPalette.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
