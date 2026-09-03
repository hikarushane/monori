import SwiftUI
import SwiftData
import MonoriCore


struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bottomNavigationHeight) private var bottomNavigationHeight
    @Environment(\.monoriUIMetrics) private var metrics
    @Query private var allCollections: [LocalCollectionModel]
    @AppStorage("library.sortOrder") private var sortOrder: LibrarySortOrder = .title
    @AppStorage("library.sortReversed") private var sortReversed = false
    @State private var searchText = ""
    @State private var sourceFilter: SourceKind?
    @State private var statusFilter: CollectionReadingStatus? = .reading
    @State private var showsSearch = false
    @State private var showsSortMenu = false
    @State private var showsSourceMenu = false
    @State private var showsStatusMenu = false
    @State private var revealedCollectionID: String?
    @State private var longPressedCollection: LocalCollectionModel?

    private var collections: [LocalCollectionModel] {
        var result = LibraryQuery.apply(allCollections, sort: sortOrder,
                           searchText: searchText, status: statusFilter)
            .filter { sourceFilter == nil || $0.sourceKind == sourceFilter }
        if sortReversed { result.reverse() }
        return result
    }

    private var sourceCountMap: [SourceKind: Int] {
        Dictionary(grouping: allCollections, by: \.sourceKind).mapValues(\.count)
    }

    private var statusCountMap: [CollectionReadingStatus: Int] {
        Dictionary(grouping: allCollections, by: \.readingStatus).mapValues(\.count)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentMargin = metrics.contentMargin(in: proxy.size.width, maxContentWidth: metrics.isRegularWidth ? .infinity : 760)
            NavigationStack {
                Group {
                    if allCollections.isEmpty {
                        globalEmptyState
                    } else if collections.isEmpty {
                        scopedEmptyState
                    } else {
                        listContent(contentMargin: contentMargin)
                    }
                }
                .background(MonoriPalette.canvas)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    libraryHeader(contentMargin: contentMargin)
                }
                .sheet(isPresented: $showsSearch) {
                    LibrarySearchSheet(allCollections: allCollections,
                                       searchText: $searchText,
                                       statusFilter: statusFilter,
                                       sourceFilter: sourceFilter)
                }
                .overlay {
                    if showsSortMenu || showsSourceMenu || showsStatusMenu || longPressedCollection != nil {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    showsSortMenu = false
                                    showsSourceMenu = false
                                    showsStatusMenu = false
                                    longPressedCollection = nil
                                }
                            }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if showsSortMenu {
                        sortDropdown
                            .padding(.top, metrics.spacing.x1)
                            .padding(.trailing, contentMargin)
                            .transition(.scale(scale: 0.95, anchor: .topTrailing)
                                .combined(with: .opacity))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if showsSourceMenu {
                        sourceMenuPopover
                            .padding(.top, metrics.spacing.x1)
                            .padding(.trailing, contentMargin)
                            .transition(.scale(scale: 0.95, anchor: .topTrailing)
                                .combined(with: .opacity))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if showsStatusMenu {
                        statusMenuPopover
                            .padding(.top, metrics.spacing.x1)
                            .padding(.trailing, contentMargin)
                            .transition(.scale(scale: 0.95, anchor: .topTrailing)
                                .combined(with: .opacity))
                    }
                }
                .overlay(alignment: .trailing) {
                    if let collection = longPressedCollection {
                        readingStatusDropdown(for: collection)
                            .padding(.trailing, contentMargin)
                            .transition(.scale(scale: 0.95, anchor: .trailing)
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
    }

    private func libraryHeader(contentMargin: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("書庫")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(MonoriPalette.ink)

                Spacer()

                HStack(spacing: metrics.spacing.x1 * 0.5) {
                    NavigationLink(value: LibraryRoute.history) {
                        LibraryClockIcon()
                            .stroke(MonoriPalette.ink,
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: metrics.primaryActionIconSize,
                                   height: metrics.primaryActionIconSize)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閱歷")
                    .accessibilityIdentifier("smoke.readingHistoryButton")

                    Button { showsSearch = true } label: {
                        LibrarySearchIcon()
                            .stroke(MonoriPalette.ink,
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: metrics.primaryActionIconSize,
                                   height: metrics.primaryActionIconSize)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("搜尋書庫")
                    .accessibilityIdentifier("smoke.librarySearchButton")

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showsSortMenu.toggle()
                            showsSourceMenu = false
                            showsStatusMenu = false
                        }
                    } label: {
                        LibrarySortIcon()
                            .stroke(MonoriPalette.ink,
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: metrics.primaryActionIconSize,
                                   height: metrics.primaryActionIconSize)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("排序")
                    .accessibilityIdentifier("smoke.librarySortMenu")
                }
            }

            HStack {
                Text("共 \(collections.count) 部作品")
                    .font(.system(size: 13, weight: .medium))
                    .kerning(0.2)
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .accessibilityIdentifier("smoke.librarySummary")

                Spacer()

                HStack(spacing: 8) {
                    sourceFilterPill
                    statusFilterPill
                }
            }
        }
        .frame(maxWidth: metrics.isRegularWidth ? .infinity : 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, contentMargin)
        .padding(.top, metrics.spacing.x3)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
        .background(MonoriPalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }

    private var sourceFilterPill: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                showsSourceMenu.toggle()
                showsStatusMenu = false
                showsSortMenu = false
            }
        } label: {
            HStack(spacing: 6) {
                SourceLayersIcon()
                    .stroke(uguisuGreen,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 13, height: 13)
                Text("來源")
                    .lineLimit(1)
                PillChevronDown()
                    .stroke(Color(uiColor: .systemGray),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 10)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(MonoriPalette.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .fixedSize()
            .background(Color(red: 0xF2/255, green: 0xF0/255, blue: 0xED/255),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("來源篩選")
        .accessibilityIdentifier("smoke.librarySourceMenu")
    }

    private var statusFilterPill: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                showsStatusMenu.toggle()
                showsSourceMenu = false
                showsSortMenu = false
            }
        } label: {
            HStack(spacing: 6) {
                Text(statusFilter?.label ?? "全部")
                    .lineLimit(1)
                PillChevronDown()
                    .stroke(Color(uiColor: .systemGray),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 10)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(MonoriPalette.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .fixedSize()
            .background(Color(red: 0xF2/255, green: 0xF0/255, blue: 0xED/255),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("閱讀狀態：\(statusFilter?.label ?? "全部")")
        .accessibilityIdentifier("smoke.libraryStatusMenu")
    }

    private func listContent(contentMargin: CGFloat) -> some View {
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
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .onEnded { _ in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.easeOut(duration: 0.15)) {
                                longPressedCollection = collection
                            }
                        }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: contentMargin,
                                           bottom: 0, trailing: contentMargin))
                .listRowBackground(MonoriPalette.canvas)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MonoriPalette.canvas)
        .listRowSeparatorTint(MonoriPalette.divider)
        .contentMargins(
            .bottom,
            bottomNavigationHeight + metrics.spacing.x2,
            for: .scrollContent
        )
        .refreshable { await env.autoCheck.runForced() }
        .navigationDestination(for: String.self) { id in
            if let collection = allCollections.first(where: { $0.id == id }) {
                CollectionTOCView(collection: collection)
            }
        }
        .navigationDestination(for: LibraryRoute.self) { route in
            switch route {
            case .history:
                ReadingHistoryView()
            }
        }
    }

    // MARK: - Uguisu Zen dropdown menus

    private func dismissAllMenus() {
        withAnimation(.easeOut(duration: 0.15)) {
            showsSortMenu = false
            showsSourceMenu = false
            showsStatusMenu = false
        }
    }

    private func uguisuMenuRow<Icon: View>(
        @ViewBuilder icon: @escaping () -> Icon,
        label: String,
        count: Int? = nil,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        UguisuMenuRow(icon: icon, label: label, count: count, selected: selected) {
            action()
            dismissAllMenus()
        }
    }


    private var sortDropdown: some View {
        UguisuMenuContainer {
            uguisuMenuRow(
                icon: {
                    LibraryClockIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "最近閱讀",
                selected: sortOrder == .recentlyRead
            ) { sortOrder = .recentlyRead }

            uguisuMenuRow(
                icon: {
                    MenuBoltIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "最近更新",
                selected: sortOrder == .recentlyUpdated
            ) { sortOrder = .recentlyUpdated }

            uguisuMenuRow(
                icon: {
                    MenuFolderIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "作品名稱",
                selected: sortOrder == .title
            ) { sortOrder = .title }

            uguisuMenuRow(
                icon: {
                    MenuPersonIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "作者名稱",
                selected: sortOrder == .author
            ) { sortOrder = .author }

            UguisuMenuDivider()

            Button {
                sortReversed.toggle()
            } label: {
                HStack(spacing: 10) {
                    PillChevronDown()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 17, height: 17)
                        .rotationEffect(.degrees(sortReversed ? 180 : 0))
                    Text(sortReversed ? "升序" : "降序")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(MonoriPalette.ink)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var sourceMenuPopover: some View {
        UguisuMenuContainer {
            uguisuMenuRow(
                icon: {
                    SourceLayersIcon()
                        .stroke(uguisuGreen,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "全部來源",
                count: allCollections.count,
                selected: sourceFilter == nil
            ) { sourceFilter = nil }

            UguisuMenuDivider()

            ForEach(SourceRegistry.all) { provider in
                uguisuMenuRow(
                    icon: {
                        SourceGlyph(kind: provider.kind)
                            .foregroundStyle(uguisuGreen)
                    },
                    label: provider.displayName,
                    count: sourceCountMap[provider.kind] ?? 0,
                    selected: sourceFilter == provider.kind
                ) { sourceFilter = provider.kind }
            }
        }
    }

    private var statusMenuPopover: some View {
        UguisuMenuContainer {
            uguisuMenuRow(
                icon: {
                    SourceLayersIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "全部狀態",
                count: allCollections.count,
                selected: statusFilter == nil
            ) { statusFilter = nil }

            UguisuMenuDivider()

            uguisuMenuRow(
                icon: {
                    MenuBookmarkIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "追更中",
                count: statusCountMap[.reading] ?? 0,
                selected: statusFilter == .reading
            ) { statusFilter = .reading }

            uguisuMenuRow(
                icon: {
                    MenuCircleCheckIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "已讀完",
                count: statusCountMap[.finished] ?? 0,
                selected: statusFilter == .finished
            ) { statusFilter = .finished }

            uguisuMenuRow(
                icon: {
                    MenuCircleMinusIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: "棄坑",
                count: statusCountMap[.dropped] ?? 0,
                selected: statusFilter == .dropped
            ) { statusFilter = .dropped }
        }
    }


    private func readingStatusDropdown(for collection: LocalCollectionModel) -> some View {
        UguisuMenuContainer {
            uguisuMenuRow(
                icon: {
                    MenuBookmarkIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: CollectionReadingStatus.reading.label,
                selected: collection.readingStatus == .reading
            ) {
                env.store.setReadingStatus(.reading, for: collection)
                longPressedCollection = nil
            }

            uguisuMenuRow(
                icon: {
                    MenuCircleCheckIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: CollectionReadingStatus.finished.label,
                selected: collection.readingStatus == .finished
            ) {
                env.store.setReadingStatus(.finished, for: collection)
                longPressedCollection = nil
            }

            uguisuMenuRow(
                icon: {
                    MenuCircleMinusIcon()
                        .stroke(uguisuMenuIconGrey,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                },
                label: CollectionReadingStatus.dropped.label,
                selected: collection.readingStatus == .dropped
            ) {
                env.store.setReadingStatus(.dropped, for: collection)
                longPressedCollection = nil
            }
        }
    }

    @ViewBuilder
    private var runningOverlay: some View {
        if env.autoCheck.isRunning {
            VStack(alignment: .leading, spacing: metrics.spacing.x1) {
                Text("檢查新章節中 \(env.autoCheck.checkedCount)/\(env.autoCheck.totalCount)")
                    .font(MonoriTypography.ui(metrics.footnoteFontSize, relativeTo: .footnote, weight: .medium))
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.ink)
                ProgressView()
                    .tint(MonoriPalette.highlight)
                    .progressViewStyle(.linear)
            }
            .padding(metrics.spacing.x2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonoriPalette.surface,
                        in: RoundedRectangle(cornerRadius: MonoriRadius.container))
            .overlay {
                RoundedRectangle(cornerRadius: MonoriRadius.container)
                    .stroke(MonoriPalette.divider, lineWidth: 1)
            }
            .padding(.horizontal, metrics.contentHorizontalPadding)
            .padding(.bottom, metrics.spacing.x2)
            .accessibilityIdentifier("smoke.autoCheckSpinner")
        }
    }

    private func row(_ collection: LocalCollectionModel) -> some View {
        HStack(alignment: .center, spacing: metrics.libraryRowContentSpacing) {
            SourceGlyph(kind: collection.sourceKind)
                .frame(width: metrics.librarySourceIconSize, height: metrics.librarySourceIconSize)
                .foregroundStyle(MonoriPalette.secondaryInk)
                .frame(width: metrics.librarySourceSlotWidth)
                .accessibilityIdentifier("smoke.collectionSourceIcon")
            VStack(alignment: .leading, spacing: metrics.rowInformationSpacing) {
                Text(collection.title)
                    .font(MonoriTypography.ui(metrics.libraryTitleFontSize,
                                               relativeTo: .headline, weight: .semibold))
                    .foregroundStyle(MonoriPalette.ink)
                if let creator = collection.creatorName, !creator.isEmpty {
                    Text("作者：\(creator)")
                        .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                                   relativeTo: .subheadline))
                        .foregroundStyle(MonoriPalette.secondaryInk)
                }
                HStack(spacing: 6) {
                    Text("\(collection.chapters.count) 章")
                    if let updated = collection.lastNewChapterAt {
                        Text("・更新於 \(updated.formatted(.relative(presentation: .named).locale(Locale(identifier: "zh-Hant"))))")
                    }
                }
                .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                           relativeTo: .subheadline))
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
                    .font(MonoriTypography.ui(metrics.captionFontSize, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(MonoriPalette.ink)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(MonoriPalette.highlight,
                                in: RoundedRectangle(cornerRadius: MonoriRadius.control))
                    .accessibilityIdentifier("smoke.libraryUnreadBadge")
                    .accessibilityLabel("\(collection.unreadCount) 個新章節")
            }
        }
        .padding(.vertical, metrics.rowVerticalPadding)
    }

    private var globalEmptyState: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            Text("尚無收藏")
                .font(MonoriTypography.ui(metrics.libraryEmptyStateTitleFontSize,
                                           relativeTo: .title2, weight: .semibold))
                .foregroundStyle(MonoriPalette.ink)
            Text("在「瀏覽」分頁開啟 Patreon 文章的系列頁面，然後點選「匯入」。")
                .font(MonoriTypography.ui(metrics.emptyStateDescriptionFontSize,
                                           relativeTo: .body))
                .foregroundStyle(MonoriPalette.secondaryInk)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: metrics.isRegularWidth ? .infinity : 760, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, metrics.contentHorizontalPadding)
    }

    private var scopedEmptyState: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            Text(scopedEmptyTitle)
                .font(MonoriTypography.ui(metrics.emptyStateTitleFontSize,
                                           relativeTo: .title3, weight: .semibold))
                .foregroundStyle(MonoriPalette.ink)
            if let hint = scopedEmptyHint {
                Text(hint)
                    .font(MonoriTypography.ui(metrics.emptyStateDescriptionFontSize,
                                               relativeTo: .body))
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .lineSpacing(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: metrics.isRegularWidth ? .infinity : 760, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, metrics.contentHorizontalPadding)
    }

    private var scopedEmptyTitle: String {
        if sourceFilter != nil {
            return "此來源沒有符合目前狀態的作品"
        }
        guard let statusFilter else { return "沒有符合條件的作品" }
        switch statusFilter {
        case .reading: return "目前沒有追更中的作品"
        case .finished: return "還沒有完食的作品"
        case .dropped: return "沒有棄坑的作品"
        }
    }

    private var scopedEmptyHint: String? {
        if sourceFilter != nil { return nil }
        guard statusFilter == .finished else { return nil }
        return "可在作品的章節選單中改成「完食」。"
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

#Preview("書庫・已讀完") {
    let env = PreviewSupport.statusVariedEnvironment()
    NavigationStack {
        LibraryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}

#Preview("書庫・狀態篩選為空") {
    let env = PreviewSupport.emptyEnvironment()
    NavigationStack {
        LibraryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}
#endif

private enum LibraryRoute: Hashable {
    case history
}

private struct LibrarySearchSheet: View {
    let allCollections: [LocalCollectionModel]
    @Binding var searchText: String
    let statusFilter: CollectionReadingStatus?
    let sourceFilter: SourceKind?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoriUIMetrics) private var metrics

    private var results: [LocalCollectionModel] {
        LibraryQuery.apply(allCollections, sort: .title,
                           searchText: searchText, status: statusFilter)
            .filter { sourceFilter == nil || $0.sourceKind == sourceFilter }
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
                            VStack(alignment: .leading, spacing: metrics.rowInformationSpacing) {
                                Text(collection.title)
                                    .font(MonoriTypography.ui(metrics.libraryTitleFontSize,
                                                              relativeTo: .headline,
                                                              weight: .semibold))
                                if let creator = collection.creatorName, !creator.isEmpty {
                                    Text("作者：\(creator)")
                                        .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                                                   relativeTo: .subheadline))
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
