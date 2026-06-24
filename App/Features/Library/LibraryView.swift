import SwiftUI
import SwiftData
import MonoriCore

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \LocalCollectionModel.title) private var collections: [LocalCollectionModel]

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(collections) { collection in
                            NavigationLink(value: collection.id) {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: SourceRegistry.provider(for: collection.sourceKind).iconSystemName)
                                        .font(.title3)
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
                                        Text("\(collection.chapters.count) 章")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { env.store.deleteCollection(collections[i]) }
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: String.self) { id in
                        if let collection = collections.first(where: { $0.id == id }) {
                            CollectionTOCView(collection: collection)
                        }
                    }
                }
            }
            .navigationTitle("書庫")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("尚無收藏", systemImage: "books.vertical")
        } description: {
            Text("在「瀏覽」分頁開啟 Patreon 文章的系列頁面，然後點選「匯入所有章節」。")
        }
    }
}
