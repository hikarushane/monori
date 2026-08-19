import SwiftUI
import MonoriCore

struct ReaderTarget: Identifiable {
    let id: String
}

struct CollectionTOCView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
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
        case .newChapters: return "已匯入新章節"
        case .upToDate: return "已是最新"
        case .needsLogin: return "需要登入"
        case .blocked: return "需要人工驗證"
        case .unsupported: return "不支援"
        case .failed, nil: return "無法檢查"
        }
    }

    private var refreshAlertMessage: String {
        let sourceName = SourceRegistry.provider(for: collection.sourceKind).displayName
        switch refreshOutcome {
        case .newChapters(let count):
            return "已匯入 \(count) 個新章節。"
        case .upToDate:
            return "書庫已與此收藏同步。"
        case .needsLogin:
            return "\(sourceName) 要求登入。請開啟「瀏覽」分頁登入後重試。"
        case .blocked:
            return "\(sourceName) 顯示人工驗證頁面。請開啟「瀏覽」分頁完成驗證後重試。"
        case .unsupported:
            return "此來源不支援自動檢查新章節。"
        case .failed, nil:
            return "無法載入收藏頁面。請確認網路連線後重試。"
        }
    }

    // Extracted so the get/set closures don't bloat the toolbar ViewBuilder
    // expression past the type-checker's time budget.
    private var readingStatusBinding: Binding<CollectionReadingStatus> {
        Binding(get: { collection.readingStatus },
                set: { env.store.setReadingStatus($0, for: collection) })
    }

    // The ••• menu content lives here so the toolbar expression stays small
    // enough for the Swift type-checker (inlining it times out compilation).
    @ViewBuilder
    private var chapterOptionsMenu: some View {
        Picker("閱讀狀態", selection: readingStatusBinding) {
            ForEach(CollectionReadingStatus.allCases, id: \.self) { status in
                Text(status.label).tag(status)
            }
        }
        .accessibilityIdentifier("smoke.collectionStatusMenu")
        Button {
            env.store.markAllRead(collection)
        } label: {
            Label("全部標示為已閱讀", systemImage: "checkmark.circle")
        }
        .disabled(collection.unreadCount == 0)
        .accessibilityIdentifier("smoke.markAllReadButton")
        Button {
            collection.sortDirection =
                collection.sortDirection == .oldestToNewest ? .newestToOldest : .oldestToNewest
        } label: {
            Label("反轉順序", systemImage: "arrow.up.arrow.down")
        }
        if collection.sourceKind.supportsAutoCheck {
            Button {
                refreshing = true
                Task {
                    refreshOutcome = await env.refreshCollection(collection)
                    env.store.recordCheck(collection)
                    refreshing = false
                    showRefreshResult = true
                }
            } label: {
                Label("檢查新章節", systemImage: "arrow.triangle.2.circlepath")
            }
            .accessibilityIdentifier("smoke.refreshChaptersButton")
        } else {
            Label("此來源不支援檢查新章節", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collectionHeader
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)

            List {
                ForEach(chapters) { chapter in
                    chapterRow(chapter)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            env.store.markChapterOpened(chapter)
                            readerTarget = ReaderTarget(id: chapter.id)
                        }
                        .swipeActions {
                            Button("刪除", role: .destructive) { env.store.delete(chapter) }
                            Button("重新命名") {
                                renameTarget = chapter
                                renameText = chapter.title
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回書庫")

                Spacer()

                if refreshing {
                    ProgressView().controlSize(.small)
                        .accessibilityIdentifier("smoke.refreshChaptersButton")
                } else {
                    Menu {
                        chapterOptionsMenu
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("章節選項")
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(Color(.systemBackground))
        }
        .fullScreenCover(item: $readerTarget) { target in
            if let chapter = chapters.first(where: { $0.id == target.id }) {
                ReaderView(chapter: chapter)
            }
        }
        .alert("重新命名章節", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } })) {
            TextField("標題", text: $renameText)
            Button("儲存") {
                if let t = renameTarget { env.store.rename(t, to: renameText) }
                renameTarget = nil
            }
            Button("取消", role: .cancel) { renameTarget = nil }
        }
        .alert(refreshAlertTitle, isPresented: $showRefreshResult) {
            Button("確定") {}
        } message: {
            Text(refreshAlertMessage)
        }
        .overlay(alignment: .bottom) {
            if refreshing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在檢查新章節⋯大型收藏可能需要幾分鐘。")
                        .font(.footnote)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.bar, in: Capsule())
                .padding(.bottom, 12)
                .accessibilityIdentifier("smoke.refreshStatusBanner")
            }
        }
    }

    private var collectionHeader: some View {
        let sourceName = SourceRegistry.provider(for: collection.sourceKind).displayName
        let author = collection.creatorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 12) {
            sourceChip(sourceName)

            Text(collection.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                if let author, !author.isEmpty {
                    metadataLine(label: "作者", value: author)
                }
                Text("共 \(chapters.count) 章")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func sourceChip(_ sourceName: String) -> some View {
        HStack(spacing: 7) {
            SourceGlyph(kind: collection.sourceKind)
                .frame(width: 14, height: 14)
            Text(sourceName)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.10), in: Capsule())
    }

    private func metadataLine(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary.opacity(0.72))
        }
        .font(.subheadline)
    }

    private func chapterRow(_ chapter: LocalChapterModel) -> some View {
        let text = ChapterTextFormatter.presentation(storedTitle: chapter.title,
                                                     urlString: chapter.urlString)

        return HStack(alignment: .center, spacing: 8) {
            Text(text.title)
                .font(.body.weight(.regular))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if chapter.isNew {
                Text("新")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("新章節")
            }
            Button {
                env.store.toggleBookmark(chapter)
                DiagnosticLog.shared.log(category: "bookmark",
                    "TOC bookmark \(chapter.isBookmarked ? "set" : "cleared")")
            } label: {
                Image(systemName: chapter.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(chapter.isBookmarked ? Color.accentColor : Color.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(chapter.isBookmarked ? "移除書籤" : "加入書籤")
            .accessibilityIdentifier("smoke.chapterBookmarkButton")
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 18))
    }
}
