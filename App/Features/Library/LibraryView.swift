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

    private var collections: [LocalCollectionModel] {
        LibraryQuery.apply(allCollections, sort: sortOrder,
                           searchText: searchText, status: statusFilter)
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
            .navigationTitle("書庫")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        sortFilterMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("排序與篩選")
                    .accessibilityIdentifier("smoke.librarySortMenu")
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
        .searchable(text: $searchText, prompt: "書名或作者")
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
        Picker("狀態", selection: $statusFilter) {
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
                        Text("・更新於 \(updated.formatted(.relative(presentation: .named)))")
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
