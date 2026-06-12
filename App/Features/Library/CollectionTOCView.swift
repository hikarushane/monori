import SwiftUI
import ChapterlyCore

struct ReaderTarget: Identifiable {
    let id: String
}

struct CollectionTOCView: View {
    @Environment(AppEnvironment.self) private var env
    let collection: LocalCollectionModel
    @State private var readerTarget: ReaderTarget?
    @State private var refreshing = false
    @State private var refreshOutcome: CollectionRefreshOutcome?
    @State private var showRefreshResult = false
    @State private var renameTarget: LocalChapterModel?
    @State private var renameText = ""

    private var chapters: [LocalChapterModel] { env.store.orderedChapters(of: collection) }

    private var refreshAlertTitle: String {
        switch refreshOutcome {
        case .newChapters: return "New chapters imported"
        case .upToDate: return "Up to date"
        case .needsLogin: return "Login required"
        case .failed, nil: return "Could not check"
        }
    }

    private var refreshAlertMessage: String {
        switch refreshOutcome {
        case .newChapters(let count):
            return "Imported \(count) new chapter\(count == 1 ? "" : "s")."
        case .upToDate:
            return "Your library already matches this collection."
        case .needsLogin:
            return "Patreon asked for login. Open the Browse tab, log in, then try again."
        case .failed, nil:
            return "Could not load the collection page. Check your connection and try again."
        }
    }

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
                Button {
                    refreshing = true
                    Task {
                        refreshOutcome = await env.refreshCollection(collection)
                        refreshing = false
                        showRefreshResult = true
                    }
                } label: {
                    if refreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(refreshing)
                .accessibilityLabel("Check for new chapters")
                .accessibilityIdentifier("smoke.refreshChaptersButton")
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
        .alert(refreshAlertTitle, isPresented: $showRefreshResult) {
            Button("OK") {}
        } message: {
            Text(refreshAlertMessage)
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
                Button {
                    env.store.toggleBookmark(chapter)
                } label: {
                    Image(systemName: chapter.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(chapter.isBookmarked ? Color.accentColor : Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(chapter.isBookmarked ? "Remove bookmark" : "Bookmark this chapter")
                .accessibilityIdentifier("smoke.chapterBookmarkButton")
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
