import SwiftUI
import SwiftData
import MonoriCore

struct ReadingHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LocalReadingHistoryEntry.openedAt, order: .reverse)
    private var entries: [LocalReadingHistoryEntry]
    @State private var showsClearConfirmation = false
    @State private var readerTarget: ReaderTarget?

    private var sections: [ReadingHistoryDaySection] {
        ReadingHistoryQuery.sections(from: entries)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .background(MonoriPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .fullScreenCover(item: $readerTarget) { target in
            if let chapter = env.store.chapter(id: target.id) {
                ReaderView(chapter: chapter)
                    .preferredColorScheme(env.appPrefs.appearance.colorScheme)
            }
        }
        .confirmationDialog("清除所有閱歷？", isPresented: $showsClearConfirmation,
                            titleVisibility: .visible) {
            Button("清除閱歷", role: .destructive) {
                try? env.store.clearReadingHistory()
            }
        } message: {
            Text("這不會刪除書庫、書籤或閱讀進度。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MonoriSpacing.x1) {
            HStack(alignment: .firstTextBaseline) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(MonoriTypography.ui(20, relativeTo: .title3, weight: .medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")

                Text("閱歷")
                    .font(MonoriTypography.ui(24, relativeTo: .title2, weight: .bold))
                    .tracking(-0.4)

                Spacer()

                if !entries.isEmpty {
                    Button {
                        showsClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(MonoriTypography.ui(18, relativeTo: .body, weight: .medium))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除閱歷")
                    .accessibilityIdentifier("smoke.clearReadingHistoryButton")
                }
            }
            .foregroundStyle(MonoriPalette.ink)

            Text("共 \(entries.count) 筆紀錄")
                .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .medium))
                .tracking(MonoriTypography.uiTracking)
                .foregroundStyle(MonoriPalette.secondaryInk)
        }
        .padding(.horizontal, MonoriSpacing.x3)
        .padding(.top, MonoriSpacing.x3)
        .padding(.bottom, MonoriSpacing.x2)
        .background(MonoriPalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MonoriPalette.divider).frame(height: 1)
        }
    }

    private var historyList: some View {
        List {
            ForEach(sections, id: \.day) { section in
                Section {
                    ForEach(section.entries, id: \.id) { entry in
                        historyRow(entry)
                            .accessibilityIdentifier("smoke.readingHistoryRow")
                    }
                } header: {
                    Text(sectionTitle(for: section.day))
                        .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .semibold))
                        .tracking(MonoriTypography.uiTracking)
                        .foregroundStyle(MonoriPalette.secondaryInk)
                        .textCase(nil)
                }
                .listRowBackground(MonoriPalette.canvas)
                .listRowInsets(EdgeInsets(top: 0, leading: MonoriSpacing.x3,
                                          bottom: 0, trailing: MonoriSpacing.x3))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MonoriPalette.canvas)
        .listRowSeparatorTint(MonoriPalette.divider)
        .accessibilityIdentifier("smoke.readingHistoryList")
    }

    private func historyRow(_ entry: LocalReadingHistoryEntry) -> some View {
        let chapter = env.store.chapter(id: entry.chapterID)
        let isAvailable = chapter != nil
        return Button {
            if let chapter {
                readerTarget = ReaderTarget(id: chapter.id)
            }
        } label: {
            HStack(alignment: .top, spacing: MonoriSpacing.x2) {
                SourceGlyph(kind: SourceKind(rawValue: entry.sourceKindRaw) ?? .patreon)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(MonoriPalette.secondaryInk)
                    .frame(width: 24)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.chapterTitle)
                        .font(MonoriTypography.ui(16, relativeTo: .body, weight: .medium))
                        .foregroundStyle(isAvailable ? MonoriPalette.ink : MonoriPalette.secondaryInk)

                    HStack(spacing: 6) {
                        Text(entry.collectionTitle)
                        Text("·")
                        Text(timeString(entry.openedAt))
                    }
                    .font(MonoriTypography.ui(13, relativeTo: .footnote))
                    .foregroundStyle(MonoriPalette.secondaryInk)

                    if !isAvailable {
                        Text("已從書庫移除")
                            .font(MonoriTypography.ui(12, relativeTo: .caption))
                            .foregroundStyle(MonoriPalette.secondaryInk)
                    }
                }

                Spacer()
            }
            .padding(.vertical, MonoriSpacing.x1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel(accessibilityLabel(for: entry, isAvailable: isAvailable))
    }

    private func sectionTitle(for day: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(day) { return "今天" }
        if calendar.isDateInYesterday(day) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hant")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hant")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func accessibilityLabel(for entry: LocalReadingHistoryEntry,
                                     isAvailable: Bool) -> String {
        var label = "\(entry.chapterTitle)，\(entry.collectionTitle)，\(timeString(entry.openedAt))"
        if !isAvailable { label += "，已從書庫移除，無法開啟" }
        return label
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MonoriSpacing.x2) {
            Text("還沒有閱歷")
                .font(MonoriTypography.ui(18, relativeTo: .title3, weight: .semibold))
                .foregroundStyle(MonoriPalette.ink)
            Text("開啟書庫中的章節後，閱讀紀錄會出現在這裡。")
                .font(MonoriTypography.ui(16, relativeTo: .body))
                .foregroundStyle(MonoriPalette.secondaryInk)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(MonoriSpacing.x3)
    }
}

#if DEBUG
#Preview("閱歷・有內容") {
    let env = PreviewSupport.historyEnvironment()
    NavigationStack {
        ReadingHistoryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}

#Preview("閱歷・空狀態") {
    let env = PreviewSupport.emptyHistoryEnvironment()
    NavigationStack {
        ReadingHistoryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
}

#Preview("閱歷・大字體", traits: .fixedLayout(width: 430, height: 932)) {
    let env = PreviewSupport.historyEnvironment()
    NavigationStack {
        ReadingHistoryView()
    }
    .environment(env)
    .modelContainer(env.store.container)
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
