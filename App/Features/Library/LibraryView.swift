import SwiftUI
import SwiftData
import ChapterlyCore

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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(collection.title).font(.headline)
                                    if let creator = collection.creatorName, !creator.isEmpty {
                                        Text("作者：\(creator)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(collection.chapters.count) chapters")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
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
            .navigationTitle("Library")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No collections yet", systemImage: "books.vertical")
        } description: {
            Text("Browse to a Patreon post, open its series page, and tap \u{201c}Import visible chapters\u{201d}.")
        }
    }
}
