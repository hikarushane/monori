import SwiftUI
import ChapterlyCore

struct ReaderTarget: Identifiable {
    let id: String
}

struct CollectionTOCView: View {
    @Environment(AppEnvironment.self) private var env
    let collection: LocalCollectionModel
    @State private var readerTarget: ReaderTarget?
    @State private var showAddSheet = false
    @State private var newTitle = ""
    @State private var newURL = ""
    @State private var renameTarget: LocalChapterModel?
    @State private var renameText = ""

    private var chapters: [LocalChapterModel] { env.store.orderedChapters(of: collection) }

    var body: some View {
        List {
            ForEach(chapters) { chapter in
                chapterRow(chapter)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        readerTarget = ReaderTarget(id: chapter.id)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { env.store.delete(chapter) }
                        Button("Rename") {
                            renameTarget = chapter
                            renameText = chapter.title
                        }
                    }
            }
            .onMove { source, destination in
                env.store.moveChapters(in: collection, from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    collection.sortDirection =
                        collection.sortDirection == .oldestToNewest ? .newestToOldest : .oldestToNewest
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Reverse chapter order")
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add chapter manually")
                EditButton()
            }
        }
        .fullScreenCover(item: $readerTarget) { target in
            if let chapter = chapters.first(where: { $0.id == target.id }) {
                ReaderView(chapter: chapter)
            }
        }
        .alert("Rename chapter", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } })) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let t = renameTarget { env.store.rename(t, to: renameText) }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                Form {
                    TextField("Title", text: $newTitle)
                    TextField("Patreon post URL", text: $newURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                .navigationTitle("Add chapter")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            try? env.store.addManualChapter(to: collection, title: newTitle, urlString: newURL)
                            newTitle = ""; newURL = ""; showAddSheet = false
                        }
                        .disabled(newTitle.isEmpty || URLNormalizer.normalize(newURL) == nil)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func chapterRow(_ chapter: LocalChapterModel) -> some View {
        let text = ChapterTextFormatter.presentation(storedTitle: chapter.title,
                                                     urlString: chapter.urlString)
        let previewText = chapter.excerpt ?? text.preview

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(text.title)
                        .font(.body.weight(.medium))
                    if let date = chapter.visibleDateText {
                        Text(date).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let progress = chapter.readingProgress {
                    if progress >= 0.97 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Finished")
                    } else {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(Int(progress * 100)) percent read")
                    }
                }
            }
            if let preview = previewText {
                Text(preview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
