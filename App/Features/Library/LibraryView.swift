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
    @State private var searchText = ""
    @State private var sourceFilter: SourceKind?
    @State private var statusFilter: CollectionReadingStatus = .reading
    @State private var showsSearch = false
    @State private var showsSortMenu = false
    @State private var showsStatusMenu = false
    @State private var revealedCollectionID: String?

    private var collections: [LocalCollectionModel] {
        LibraryQuery.apply(allCollections, sort: sortOrder,
                           searchText: searchText, status: statusFilter)
            .filter { sourceFilter == nil || $0.sourceKind == sourceFilter }
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
                    if showsSortMenu || showsStatusMenu {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    showsSortMenu = false
                                    showsStatusMenu = false
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
                    if showsStatusMenu {
                        statusDropdown
                            .padding(.top, 78)
                            .padding(.trailing, contentMargin)
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
    }

    private func libraryHeader(contentMargin: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: metrics.spacing.x1) {
            HStack(alignment: .firstTextBaseline) {
                Text("書庫")
                    .font(MonoriTypography.ui(metrics.largeTitleFontSize, relativeTo: .largeTitle, weight: .bold))
                    .tracking(-0.6)

                Spacer()

                HStack(spacing: 18) {
                    NavigationLink(value: LibraryRoute.history) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(MonoriTypography.ui(metrics.primaryActionIconSize,
                                                       relativeTo: .title3, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閱歷")
                    .accessibilityIdentifier("smoke.readingHistoryButton")

                    Button {
                        showsSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(MonoriTypography.ui(metrics.primaryActionIconSize,
                                                       relativeTo: .title3, weight: .medium))
                            .frame(width: 44, height: 44)
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
                            .frame(width: metrics.primaryActionIconSize,
                                   height: metrics.primaryActionIconSize)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("書庫選項")
                    .accessibilityIdentifier("smoke.librarySortMenu")
                }
                .foregroundStyle(MonoriPalette.ink)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("共 \(collections.count) 部作品")
                    .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                               relativeTo: .subheadline, weight: .medium))
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .accessibilityIdentifier("smoke.librarySummary")

                Spacer()

                statusScopeButton
            }

            sourceFilterPicker
        }
        .frame(maxWidth: metrics.isRegularWidth ? .infinity : 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, contentMargin)
        .padding(.top, metrics.spacing.x3)
        .padding(.bottom, metrics.spacing.x2)
        .background(MonoriPalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
    }

    private var statusScopeButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                showsStatusMenu.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(statusFilter.label)
                DropdownChevron()
                    .stroke(MonoriPalette.secondaryInk,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(showsStatusMenu ? 180 : 0))
            }
            .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                       relativeTo: .subheadline, weight: .medium))
            .tracking(MonoriTypography.uiTracking)
            .foregroundStyle(MonoriPalette.secondaryInk)
        }
        .offset(x: -2.5)
        .buttonStyle(.plain)
        .accessibilityLabel("閱讀狀態：\(statusFilter.label)")
        .accessibilityIdentifier("smoke.libraryStatusMenu")
    }

    private var statusDropdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(CollectionReadingStatus.allCases.enumerated()), id: \.element.rawValue) { index, status in
                if index > 0 { menuGroupDivider() }
                menuOptionRow(status.label, selected: statusFilter == status,
                              dismiss: $showsStatusMenu) {
                    statusFilter = status
                }
                .accessibilityIdentifier("smoke.libraryStatus\(status.rawValue.capitalized)")
            }
        }
        .background(MonoriPalette.surface,
                    in: RoundedRectangle(cornerRadius: MonoriRadius.container))
        .overlay {
            RoundedRectangle(cornerRadius: MonoriRadius.container)
                .stroke(MonoriPalette.divider, lineWidth: 1)
        }
        .frame(width: 130)
    }

    private var sourceFilterPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: metrics.spacing.x1) {
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
                .font(MonoriTypography.ui(metrics.filterLabelFontSize, relativeTo: .subheadline,
                                           weight: isSelected ? .semibold : .medium))
                .tracking(MonoriTypography.uiTracking)
                .foregroundStyle(MonoriPalette.ink)
                .lineLimit(1)
                .padding(.horizontal, metrics.spacing.x2)
                .padding(.vertical, metrics.spacing.x1)
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

    private var sortDropdown: some View {
        VStack(spacing: 0) {
            menuOptionRow("標題", selected: sortOrder == .title, dismiss: $showsSortMenu) { sortOrder = .title }
            menuGroupDivider()
            menuOptionRow("最近更新", selected: sortOrder == .recentlyUpdated, dismiss: $showsSortMenu) { sortOrder = .recentlyUpdated }
            menuGroupDivider()
            menuOptionRow("最近閱讀", selected: sortOrder == .recentlyRead, dismiss: $showsSortMenu) { sortOrder = .recentlyRead }
            menuGroupDivider()
            menuOptionRow("來源", selected: sortOrder == .source, dismiss: $showsSortMenu) { sortOrder = .source }
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
                               dismiss: Binding<Bool>,
                               action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(.easeOut(duration: 0.15)) {
                dismiss.wrappedValue = false
            }
        } label: {
            HStack {
                Text(title)
                    .font(MonoriTypography.ui(metrics.buttonLabelFontSize, relativeTo: .body,
                                              weight: selected ? .semibold : .regular))
                    .foregroundStyle(MonoriPalette.ink)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MonoriPalette.ink)
                }
            }
            .padding(.horizontal, metrics.spacing.x3)
            .padding(.vertical, metrics.spacing.x2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuGroupDivider() -> some View {
        Rectangle()
            .fill(MonoriPalette.divider)
            .frame(height: 1)
            .padding(.horizontal, metrics.spacing.x3)
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
        switch statusFilter {
        case .reading: return "目前沒有追更中的作品"
        case .finished: return "還沒有完食的作品"
        case .dropped: return "沒有棄坑的作品"
        }
    }

    private var scopedEmptyHint: String? {
        if sourceFilter != nil { return nil }
        switch statusFilter {
        case .finished: return "可在作品的章節選單中改成「完食」。"
        default: return nil
        }
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
    let statusFilter: CollectionReadingStatus
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
