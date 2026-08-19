import SwiftUI
import SwiftData
import MonoriCore

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allCollections: [LocalCollectionModel]
    @State private var sortOrder: LibrarySortOrder = .title
    @State private var searchText = ""
    @State private var statusFilter: CollectionReadingStatus?
    @State private var sourceFilter: SourceKind?
    @State private var showsSearch = false

    private var collections: [LocalCollectionModel] {
        LibraryQuery.apply(allCollections, sort: sortOrder,
                           searchText: searchText, status: statusFilter)
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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { libraryHeader }
            .sheet(isPresented: $showsSearch) {
                LibrarySearchSheet(allCollections: allCollections,
                                   searchText: $searchText)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("書庫")
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .tracking(-1.2)

                Spacer()

                HStack(spacing: 18) {
                    Button {
                        showsSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 21, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("搜尋書庫")
                    .accessibilityIdentifier("smoke.librarySearchButton")

                    Menu {
                        sortFilterMenu
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("書庫選項")
                    .accessibilityIdentifier("smoke.librarySortMenu")
                }
                .foregroundStyle(.primary)
            }

            Text("共 \(allCollections.count) 部作品")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("smoke.librarySummary")

            sourceFilterPicker
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
    }

    private var sourceFilterPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                sourceFilterChip(nil, title: "全部")
                ForEach(SourceRegistry.all) { provider in
                    sourceFilterChip(provider.kind, title: provider.displayName)
                }
            }
            .padding(.vertical,8)
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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemFill),
                            in: Capsule())
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
            }
            .onDelete { offsets in
                for i in offsets { env.store.deleteCollection(collections[i]) }
            }
        }
        .listStyle(.plain)
        .refreshable { await env.autoCheck.runForced() }
        .navigationDestination(for: String.self) { id in
            if let collection = allCollections.first(where: { $0.id == id }) {
                CollectionTOCView(collection: collection)
            }
        }
    }

    @ViewBuilder
    private var sortFilterMenu: some View {
        Picker("排序", selection: $sortOrder) {
            Text("標題").tag(LibrarySortOrder.title)
            Text("最近更新").tag(LibrarySortOrder.recentlyUpdated)
            Text("最近閱讀").tag(LibrarySortOrder.recentlyRead)
        }
        Picker("閱讀狀態", selection: $statusFilter) {
            Text("全部").tag(CollectionReadingStatus?.none)
            ForEach(CollectionReadingStatus.allCases, id: \.self) { status in
                Text(status.label).tag(CollectionReadingStatus?.some(status))
            }
        }
    }

    @ViewBuilder
    private var runningOverlay: some View {
        if env.autoCheck.isRunning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("檢查新章節中 \(env.autoCheck.checkedCount)/\(env.autoCheck.totalCount)")
                    .font(.footnote)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar, in: Capsule())
            .padding(.bottom, 12)
            .accessibilityIdentifier("smoke.autoCheckSpinner")
        }
    }

    private func row(_ collection: LocalCollectionModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SourceGlyph(kind: collection.sourceKind)
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityIdentifier("smoke.collectionSourceIcon")
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.title).font(.headline)
                if let creator = collection.creatorName, !creator.isEmpty {
                    Text("作者：\(creator)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text("\(collection.chapters.count) 章")
                    if let updated = collection.lastNewChapterAt {
                        Text("・更新於 \(updated.formatted(.relative(presentation: .named).locale(Locale(identifier: "zh-Hant"))))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if env.autoCheck.needsLoginCollectionIDs.contains(collection.id) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("需要登入")
            }
            if collection.unreadCount > 0 {
                Text("\(collection.unreadCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .accessibilityIdentifier("smoke.libraryUnreadBadge")
                    .accessibilityLabel("\(collection.unreadCount) 個新章節")
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("尚無收藏", systemImage: "books.vertical")
        } description: {
            Text("在「瀏覽」分頁開啟 Patreon 文章的系列頁面，然後點選「匯入」。")
        }
    }
}

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
                                Text(collection.title).font(.headline)
                                if let creator = collection.creatorName, !creator.isEmpty {
                                    Text("作者：\(creator)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("搜尋書庫")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "書名或作者")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
