import SwiftUI
import MonoriCore

struct ReaderTarget: Identifiable {
    let id: String
}

struct CollectionTOCView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoriUIMetrics) private var metrics
    let collection: LocalCollectionModel
    @State private var readerTarget: ReaderTarget?
    @State private var refreshing = false
    @State private var refreshOutcome: CollectionRefreshOutcome?
    @State private var showRefreshResult = false
    @State private var renameTarget: LocalChapterModel?
    @State private var renameText = ""
    @State private var showsOptionsMenu = false
    @State private var revealedChapterID: String?

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

    private var optionsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(CollectionReadingStatus.allCases.enumerated()), id: \.offset) { index, status in
                if index > 0 { dropdownDivider() }
                dropdownRadioRow(status.label, selected: collection.readingStatus == status) {
                    env.store.setReadingStatus(status, for: collection)
                }
            }

            Rectangle().fill(MonoriPalette.divider).frame(height: 1)

            dropdownActionRow("全部標示為已閱讀", disabled: collection.unreadCount == 0) {
                env.store.markAllRead(collection)
            }
            .accessibilityIdentifier("smoke.markAllReadButton")

            dropdownDivider()

            dropdownActionRow("反轉順序") {
                collection.sortDirection =
                    collection.sortDirection == .oldestToNewest ? .newestToOldest : .oldestToNewest
            }

            if collection.sourceKind.supportsAutoCheck {
                dropdownDivider()
                dropdownActionRow("檢查新章節") {
                    refreshing = true
                    Task {
                        refreshOutcome = await env.refreshCollection(collection)
                        env.store.recordCheck(collection)
                        refreshing = false
                        showRefreshResult = true
                    }
                }
                .accessibilityIdentifier("smoke.refreshChaptersButton")
            }
        }
        .accessibilityIdentifier("smoke.collectionStatusMenu")
        .background(MonoriPalette.surface,
                    in: RoundedRectangle(cornerRadius: MonoriRadius.container))
        .overlay {
            RoundedRectangle(cornerRadius: MonoriRadius.container)
                .stroke(MonoriPalette.divider, lineWidth: 1)
        }
        .frame(width: 220)
    }

    private func dropdownRadioRow(_ title: String, selected: Bool,
                                  action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(.easeOut(duration: 0.15)) { showsOptionsMenu = false }
        } label: {
            HStack {
                Text(title)
                    .font(MonoriTypography.ui(metrics.buttonLabelFontSize, relativeTo: .body,
                                              weight: selected ? .semibold : .regular))
                    .foregroundStyle(MonoriPalette.ink)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: metrics.accessoryIconSize, weight: .semibold))
                        .foregroundStyle(MonoriPalette.ink)
                }
            }
            .padding(.horizontal, metrics.spacing.x3)
            .padding(.vertical, metrics.spacing.x2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dropdownActionRow(_ title: String, disabled: Bool = false,
                                   action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(.easeOut(duration: 0.15)) { showsOptionsMenu = false }
        } label: {
            Text(title)
                .font(MonoriTypography.ui(metrics.buttonLabelFontSize,
                                           relativeTo: .body, weight: .regular))
                .foregroundStyle(MonoriPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, metrics.spacing.x3)
                .padding(.vertical, metrics.spacing.x2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private func dropdownDivider() -> some View {
        Rectangle()
            .fill(MonoriPalette.divider)
            .frame(height: 1)
            .padding(.horizontal, metrics.spacing.x3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collectionHeader
                .padding(.horizontal, metrics.contentHorizontalPadding)
                .padding(.top, metrics.spacing.x3)
                .padding(.bottom, metrics.spacing.x3)

            List {
                ForEach(chapters) { chapter in
                    chapterRow(chapter)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if revealedChapterID != nil {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    revealedChapterID = nil
                                }
                            } else {
                                readerTarget = ReaderTarget(id: chapter.id)
                            }
                        }
                        .chapterSwipeActions(
                            itemID: chapter.id,
                            revealedID: $revealedChapterID,
                            onDelete: { env.store.delete(chapter) },
                            onRename: {
                                renameTarget = chapter
                                renameText = chapter.title
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: metrics.contentHorizontalPadding,
                                                   bottom: 0, trailing: metrics.contentHorizontalPadding))
                        .listRowBackground(MonoriPalette.canvas)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSeparatorTint(MonoriPalette.divider)
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(MonoriPalette.canvas)
        .simultaneousGesture(tocBackSwipe)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                MonoriBackButton(accessibilityLabel: "返回書庫", action: dismiss.callAsFunction)

                Spacer()

                if refreshing {
                    Text("更新中")
                        .font(MonoriTypography.ui(11, relativeTo: .caption, weight: .semibold))
                        .tracking(MonoriTypography.uiTracking)
                        .foregroundStyle(MonoriPalette.secondaryInk)
                        .frame(width: 44, height: 44)
                        .accessibilityIdentifier("smoke.refreshChaptersButton")
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showsOptionsMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(MonoriTypography.ui(metrics.primaryActionIconSize,
                                                       relativeTo: .title3, weight: .semibold))
                            .foregroundStyle(MonoriPalette.ink)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("章節選項")
                }
            }
            .padding(.horizontal, MonoriSpacing.x2)
            .frame(height: 56)
            .background(MonoriPalette.canvas)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MonoriPalette.divider)
                    .frame(height: 1)
            }
        }
        .overlay {
            if showsOptionsMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showsOptionsMenu = false
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsOptionsMenu {
                optionsDropdown
                    .padding(.top, MonoriSpacing.x1)
                    .padding(.trailing, MonoriSpacing.x2)
                    .transition(.scale(scale: 0.95, anchor: .topTrailing)
                        .combined(with: .opacity))
            }
        }
        .fullScreenCover(item: $readerTarget) { target in
            if let chapter = chapters.first(where: { $0.id == target.id }) {
                ReaderView(chapter: chapter)
                    .preferredColorScheme(env.appPrefs.appearance.colorScheme)
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
                VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
                    Text("正在檢查新章節⋯大型收藏可能需要幾分鐘。")
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
                .accessibilityIdentifier("smoke.refreshStatusBanner")
            }
        }
    }

    private var tocBackSwipe: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard BackSwipePolicy.shouldDismissNavigation(
                    startX: value.startLocation.x,
                    translationX: value.translation.width,
                    translationY: value.translation.height
                ) else { return }
                revealedChapterID = nil
                dismiss()
            }
    }

    private var collectionHeader: some View {
        let sourceName = SourceRegistry.provider(for: collection.sourceKind).displayName
        let author = collection.creatorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            sourceChip(sourceName)

            Text(collection.title)
                .font(MonoriTypography.ui(metrics.emptyStateTitleFontSize,
                                           relativeTo: .title2, weight: .semibold))
                .foregroundStyle(MonoriPalette.ink)
                .lineLimit(3)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: metrics.rowInformationSpacing) {
                if let author, !author.isEmpty {
                    metadataLine(label: "作者", value: author)
                }
                Text("共 \(chapters.count) 章")
                    .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                               relativeTo: .subheadline))
                    .foregroundStyle(MonoriPalette.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func sourceChip(_ sourceName: String) -> some View {
        HStack(spacing: metrics.rowInformationSpacing) {
            SourceGlyph(kind: collection.sourceKind)
                .frame(width: metrics.accessoryIconSize, height: metrics.accessoryIconSize)
            Text(sourceName)
                .font(MonoriTypography.ui(metrics.secondaryFontSize,
                                           relativeTo: .caption, weight: .medium))
                .tracking(MonoriTypography.uiTracking)
        }
        .foregroundStyle(MonoriPalette.secondaryInk)
    }

    private func metadataLine(label: String, value: String) -> some View {
        HStack(spacing: metrics.rowInformationSpacing) {
            Text(label)
                .foregroundStyle(MonoriPalette.secondaryInk)
            Text(value)
                .foregroundStyle(MonoriPalette.ink)
        }
        .font(MonoriTypography.ui(metrics.secondaryFontSize, relativeTo: .subheadline))
    }

    private func chapterRow(_ chapter: LocalChapterModel) -> some View {
        let text = ChapterTextFormatter.presentation(storedTitle: chapter.title,
                                                     urlString: chapter.urlString)

        return HStack(alignment: .center, spacing: metrics.rowInformationSpacing) {
            Text(text.title)
                .font(MonoriTypography.ui(metrics.bodyFontSize, relativeTo: .body, weight: .medium))
                .foregroundStyle(MonoriPalette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if chapter.isNew {
                Text("新")
                    .font(MonoriTypography.ui(11, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(MonoriPalette.highlight)
                    .accessibilityLabel("新章節")
            }
            Button {
                env.store.toggleBookmark(chapter)
                DiagnosticLog.shared.log(category: "bookmark",
                    "TOC bookmark \(chapter.isBookmarked ? "set" : "cleared")")
            } label: {
                Image(systemName: chapter.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(MonoriTypography.ui(metrics.actionIconSize,
                                               relativeTo: .body, weight: .regular))
                    .foregroundStyle(chapter.isBookmarked ? MonoriPalette.bookmark : MonoriPalette.secondaryInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(chapter.isBookmarked ? "移除書籤" : "加入書籤")
            .accessibilityIdentifier("smoke.chapterBookmarkButton")
        }
        .padding(.vertical, metrics.rowVerticalPadding)
    }
}

#if DEBUG
#Preview("目錄・Patreon") {
    let fixture = PreviewSupport.sampleCollection(source: .patreon, chapterCount: 10)
    NavigationStack {
        CollectionTOCView(collection: fixture.collection)
    }
    .environment(fixture.env)
    .modelContainer(fixture.env.store.container)
}

#Preview("目錄・AO3") {
    let fixture = PreviewSupport.sampleCollection(source: .ao3, chapterCount: 6)
    NavigationStack {
        CollectionTOCView(collection: fixture.collection)
    }
    .environment(fixture.env)
    .modelContainer(fixture.env.store.container)
}

#Preview("目錄・大字體", traits: .fixedLayout(width: 430, height: 932)) {
    let fixture = PreviewSupport.sampleCollection(source: .patreon, chapterCount: 8)
    NavigationStack {
        CollectionTOCView(collection: fixture.collection)
    }
    .environment(fixture.env)
    .modelContainer(fixture.env.store.container)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("目錄・壓力測試") {
    let fixture = PreviewSupport.stressCollection()
    NavigationStack {
        CollectionTOCView(collection: fixture.collection)
    }
    .environment(fixture.env)
    .modelContainer(fixture.env.store.container)
}
#endif
